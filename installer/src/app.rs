use std::io::{self, IsTerminal};
use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Result, bail};
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use crossterm::execute;
use crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, List, ListItem, Padding, Paragraph, Wrap};

use crate::cli::{NiriMode, Profile, UmbraMode};
use crate::manifest::FeatureManifest;
use crate::model::{FeatureStatus, InstallPlan, MachineReport, OperationState};
use crate::planner::{InstallOptions, build_plan};
use crate::probe::ProbeContext;

const ACCENT: Color = Color::Rgb(199, 185, 255);
const CYAN: Color = Color::Rgb(116, 207, 220);
const READY: Color = Color::Rgb(119, 220, 190);
const WARN: Color = Color::Rgb(240, 190, 116);
const BAD: Color = Color::Rgb(238, 138, 174);
const MUTED: Color = Color::Rgb(125, 124, 143);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Screen {
    Welcome,
    Preflight,
    Profile,
    Integrations,
    Review,
}

impl Screen {
    const ALL: [Self; 5] = [
        Self::Welcome,
        Self::Preflight,
        Self::Profile,
        Self::Integrations,
        Self::Review,
    ];

    fn label(self) -> &'static str {
        match self {
            Self::Welcome => "WELCOME",
            Self::Preflight => "PREFLIGHT",
            Self::Profile => "PROFILE",
            Self::Integrations => "SCOPE",
            Self::Review => "REVIEW",
        }
    }
}

struct AppState {
    screen: Screen,
    profile_index: usize,
    integration_row: usize,
    niri_index: usize,
    umbra_index: usize,
    review_offset: usize,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            screen: Screen::Welcome,
            profile_index: 1,
            integration_row: 0,
            niri_index: 0,
            umbra_index: 1,
            review_offset: 0,
        }
    }
}

impl AppState {
    fn screen_index(&self) -> usize {
        Screen::ALL
            .iter()
            .position(|screen| *screen == self.screen)
            .expect("active screen is registered")
    }

    fn next_screen(&mut self) {
        let index = (self.screen_index() + 1).min(Screen::ALL.len() - 1);
        self.screen = Screen::ALL[index];
        self.review_offset = 0;
    }

    fn previous_screen(&mut self) {
        self.screen = Screen::ALL[self.screen_index().saturating_sub(1)];
        self.review_offset = 0;
    }

    fn profile(&self) -> Profile {
        Profile::ALL[self.profile_index]
    }

    fn niri(&self) -> NiriMode {
        NiriMode::ALL[self.niri_index]
    }

    fn umbra(&self) -> UmbraMode {
        UmbraMode::ALL[self.umbra_index]
    }
}

pub fn run(
    source: PathBuf,
    probe: ProbeContext,
    report: MachineReport,
    manifest: FeatureManifest,
) -> Result<Option<InstallOptions>> {
    if !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        bail!("interactive mode needs a terminal; use `astralith-installer dry-run`");
    }

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    if let Err(error) = execute!(stdout, EnterAlternateScreen) {
        let _ = disable_raw_mode();
        return Err(error.into());
    }
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = match Terminal::new(backend) {
        Ok(terminal) => terminal,
        Err(error) => {
            let _ = disable_raw_mode();
            return Err(error.into());
        }
    };

    let result = run_loop(&mut terminal, source, probe, report, manifest);
    let raw_result = disable_raw_mode();
    let screen_result = execute!(terminal.backend_mut(), LeaveAlternateScreen);
    let cursor_result = terminal.show_cursor();

    raw_result?;
    screen_result?;
    cursor_result?;
    result
}

fn run_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    source: PathBuf,
    probe: ProbeContext,
    report: MachineReport,
    manifest: FeatureManifest,
) -> Result<Option<InstallOptions>> {
    let mut state = AppState::default();
    loop {
        let plan = build_plan(
            &source,
            &probe,
            &report,
            &manifest,
            &InstallOptions {
                profile: state.profile(),
                niri: state.niri(),
                umbra: state.umbra(),
            },
        );
        terminal.draw(|frame| {
            let area = frame.area();
            let rows = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(4),
                    Constraint::Min(10),
                    Constraint::Length(3),
                ])
                .split(area);
            render_header(frame, rows[0], &state, &report);
            match state.screen {
                Screen::Welcome => render_welcome(frame, rows[1], &source),
                Screen::Preflight => render_preflight(frame, rows[1], &report, &plan),
                Screen::Profile => render_profile(frame, rows[1], &state, &plan),
                Screen::Integrations => render_integrations(frame, rows[1], &state),
                Screen::Review => render_review(frame, rows[1], &state, &plan),
            }
            render_footer(frame, rows[2], &state);
        })?;

        if event::poll(Duration::from_millis(250))?
            && let Event::Key(key) = event::read()?
        {
            if key.kind != KeyEventKind::Press {
                continue;
            }
            if matches!(
                key.code,
                KeyCode::Char('q') | KeyCode::Char('Q') | KeyCode::Esc
            ) {
                return Ok(None);
            }
            if key.code == KeyCode::Tab && key.modifiers.contains(KeyModifiers::SHIFT) {
                state.previous_screen();
                continue;
            }
            match key.code {
                KeyCode::Enter if state.screen == Screen::Review => {
                    return Ok(Some(InstallOptions {
                        profile: state.profile(),
                        niri: state.niri(),
                        umbra: state.umbra(),
                    }));
                }
                KeyCode::Tab | KeyCode::Enter => state.next_screen(),
                KeyCode::BackTab | KeyCode::Backspace => state.previous_screen(),
                KeyCode::Up | KeyCode::Char('k') => {
                    move_selection(&mut state, -1, plan.operations.len())
                }
                KeyCode::Down | KeyCode::Char('j') => {
                    move_selection(&mut state, 1, plan.operations.len())
                }
                KeyCode::Left | KeyCode::Char('h') => change_value(&mut state, -1),
                KeyCode::Right | KeyCode::Char('l') => change_value(&mut state, 1),
                KeyCode::Char('1') if state.screen == Screen::Profile => state.profile_index = 0,
                KeyCode::Char('2') if state.screen == Screen::Profile => state.profile_index = 1,
                KeyCode::Char('3') if state.screen == Screen::Profile => state.profile_index = 2,
                _ => {}
            }
        }
    }
}

fn move_selection(state: &mut AppState, delta: isize, operation_count: usize) {
    match state.screen {
        Screen::Profile => {
            state.profile_index = shifted(state.profile_index, delta, Profile::ALL.len());
        }
        Screen::Integrations => {
            state.integration_row = shifted(state.integration_row, delta, 2);
        }
        Screen::Review => {
            state.review_offset = shifted(state.review_offset, delta, operation_count.max(1));
        }
        _ => {}
    }
}

fn change_value(state: &mut AppState, delta: isize) {
    match state.screen {
        Screen::Profile => {
            state.profile_index = shifted(state.profile_index, delta, Profile::ALL.len());
        }
        Screen::Integrations if state.integration_row == 0 => {
            state.niri_index = shifted(state.niri_index, delta, NiriMode::ALL.len());
        }
        Screen::Integrations => {
            state.umbra_index = shifted(state.umbra_index, delta, UmbraMode::ALL.len());
        }
        _ => {}
    }
}

fn shifted(current: usize, delta: isize, length: usize) -> usize {
    if length == 0 {
        return 0;
    }
    (current as isize + delta).clamp(0, length as isize - 1) as usize
}

fn render_header(frame: &mut ratatui::Frame, area: Rect, state: &AppState, report: &MachineReport) {
    let tabs = Screen::ALL
        .iter()
        .enumerate()
        .flat_map(|(index, screen)| {
            let active = *screen == state.screen;
            let style = if active {
                Style::default().fg(ACCENT).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(MUTED)
            };
            let mut spans = vec![Span::styled(
                format!(" {:02} {} ", index + 1, screen.label()),
                style,
            )];
            if index + 1 != Screen::ALL.len() {
                spans.push(Span::styled(" / ", Style::default().fg(MUTED)));
            }
            spans
        })
        .collect::<Vec<_>>();
    let header = Paragraph::new(vec![
        Line::from(vec![
            Span::styled(
                "ASTRALITH",
                Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
            ),
            Span::raw("  //  DEPLOYMENT ARRAY"),
            Span::styled(
                format!(
                    "    {} / {}",
                    report.distribution.pretty_name, report.architecture
                ),
                Style::default().fg(CYAN),
            ),
        ]),
        Line::from(tabs),
    ])
    .block(Block::default().borders(Borders::BOTTOM));
    frame.render_widget(header, area);
}

fn render_welcome(frame: &mut ratatui::Frame, area: Rect, source: &std::path::Path) {
    let inner = centered(area, 72, 15);
    let copy = vec![
        Line::from(Span::styled(
            "DEPLOY ASTRALITH WITHOUT GUESSWORK",
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        )),
        Line::raw(""),
        Line::raw("Inspect the machine, resolve the Arch package plan, and review"),
        Line::raw("the Niri and Umbra scope before one confirmed transaction."),
        Line::raw(""),
        Line::from(vec![
            Span::styled("MEDIA   ", Style::default().fg(MUTED)),
            Span::raw(
                source
                    .file_name()
                    .map(|name| name.to_string_lossy().into_owned())
                    .unwrap_or_else(|| "Astralith checkout".to_string()),
            ),
        ]),
        Line::from(vec![
            Span::styled("SAFETY  ", Style::default().fg(MUTED)),
            Span::styled(
                "STAGED // JOURNALED // ROLLBACK",
                Style::default().fg(READY),
            ),
        ]),
        Line::raw(""),
        Line::from(Span::styled(
            "Press Enter or Tab to begin preflight.",
            Style::default().fg(CYAN),
        )),
    ];
    frame.render_widget(
        Paragraph::new(copy)
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true })
            .block(Block::default().padding(Padding::uniform(1))),
        inner,
    );
}

fn render_preflight(
    frame: &mut ratatui::Frame,
    area: Rect,
    report: &MachineReport,
    plan: &InstallPlan,
) {
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(42), Constraint::Percentage(58)])
        .split(area);
    let support = if report.is_arch() {
        Span::styled("SUPPORTED", Style::default().fg(READY))
    } else {
        Span::styled("INSPECTION ONLY", Style::default().fg(BAD))
    };
    let machine = Paragraph::new(vec![
        Line::from(Span::styled(
            "MACHINE VECTOR",
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        )),
        Line::raw(""),
        labelled("Distribution", &report.distribution.pretty_name),
        labelled("Architecture", &report.architecture),
        labelled(
            "Package tool",
            report.package_manager.as_deref().unwrap_or("not detected"),
        ),
        labelled(
            "Session",
            report.session_type.as_deref().unwrap_or("unknown"),
        ),
        labelled("Desktop", report.desktop.as_deref().unwrap_or("unknown")),
        labelled(
            "Display mgr",
            report.display_manager.as_deref().unwrap_or("not detected"),
        ),
        labelled("Config home", &report.config_home.display().to_string()),
        labelled("Data home", &report.data_home.display().to_string()),
        Line::raw(""),
        Line::from(vec![
            Span::styled("Adapter       ", Style::default().fg(MUTED)),
            support,
        ]),
    ])
    .block(
        Block::default()
            .title(" PREFLIGHT ")
            .borders(Borders::RIGHT)
            .padding(Padding::uniform(1)),
    );
    frame.render_widget(machine, columns[0]);

    let ready = report
        .commands
        .iter()
        .filter(|command| command.path.is_some())
        .count();
    let missing = report.commands.len() - ready;
    let conflict_count = plan
        .operations
        .iter()
        .filter(|operation| matches!(operation.state, OperationState::Conflict))
        .count();
    let mut lines = vec![
        Line::from(Span::styled(
            "CAPABILITY SWEEP",
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        )),
        Line::raw(""),
        labelled("Commands ready", &ready.to_string()),
        labelled("Commands absent", &missing.to_string()),
        labelled("Path conflicts", &conflict_count.to_string()),
        labelled(
            "Fonts resolved",
            &report
                .fonts
                .iter()
                .filter(|font| font.available)
                .count()
                .to_string(),
        ),
        labelled(
            "Portable HW",
            &format!(
                "{} battery / {} backlight / {} output",
                report.hardware.batteries,
                report.hardware.backlights,
                report.hardware.drm_connectors
            ),
        ),
        labelled(
            "Radios",
            &format!(
                "network {} / bluetooth {}",
                present(report.hardware.network_present),
                present(report.hardware.bluetooth_present)
            ),
        ),
        labelled(
            "Desktop owners",
            &report.desktop_processes.len().to_string(),
        ),
        Line::raw(""),
    ];
    for warning in &plan.warnings {
        lines.push(Line::from(Span::styled(warning, Style::default().fg(BAD))));
    }
    if plan.warnings.is_empty() {
        lines.push(Line::from(Span::styled(
            "Machine preflight is safe to continue.",
            Style::default().fg(READY),
        )));
    }
    frame.render_widget(
        Paragraph::new(lines)
            .wrap(Wrap { trim: true })
            .block(Block::default().padding(Padding::uniform(1))),
        columns[1],
    );
}

fn present(value: bool) -> &'static str {
    if value { "yes" } else { "no" }
}

fn render_profile(frame: &mut ratatui::Frame, area: Rect, state: &AppState, plan: &InstallPlan) {
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(34), Constraint::Percentage(66)])
        .split(area);
    let profile_items = Profile::ALL
        .iter()
        .enumerate()
        .map(|(index, profile)| {
            let selected = index == state.profile_index;
            let marker = if selected { "●" } else { "○" };
            ListItem::new(vec![
                Line::from(Span::styled(
                    format!("{marker} {}", profile.id().to_uppercase()),
                    if selected {
                        Style::default().fg(ACCENT).add_modifier(Modifier::BOLD)
                    } else {
                        Style::default().fg(MUTED)
                    },
                )),
                Line::from(profile_description(*profile)),
                Line::raw(""),
            ])
        })
        .collect::<Vec<_>>();
    frame.render_widget(
        List::new(profile_items).block(
            Block::default()
                .title(" FLIGHT PROFILE ")
                .borders(Borders::RIGHT)
                .padding(Padding::uniform(1)),
        ),
        columns[0],
    );

    let feature_items = plan
        .features
        .iter()
        .filter(|feature| feature.selected)
        .map(|feature| {
            let (glyph, color) = feature_marker(feature.status);
            let unavailable = feature
                .capabilities
                .iter()
                .filter(|capability| !capability.available)
                .count();
            let suffix = if unavailable == 0 {
                "ready".to_string()
            } else {
                format!("{unavailable} dependency gap(s)")
            };
            ListItem::new(Line::from(vec![
                Span::styled(format!("{glyph}  "), Style::default().fg(color)),
                Span::styled(
                    &feature.label,
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::styled(format!("    {suffix}"), Style::default().fg(MUTED)),
            ]))
        })
        .collect::<Vec<_>>();
    frame.render_widget(
        List::new(feature_items).block(
            Block::default()
                .title(" SELECTED CAPABILITIES ")
                .padding(Padding::uniform(1)),
        ),
        columns[1],
    );
}

fn render_integrations(frame: &mut ratatui::Frame, area: Rect, state: &AppState) {
    let inner = centered(area, 76, 15);
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(6),
            Constraint::Length(6),
            Constraint::Min(1),
        ])
        .split(inner);
    render_choice(
        frame,
        rows[0],
        state.integration_row == 0,
        "NIRI CONFIGURATION",
        state.niri().label(),
        match state.niri() {
            NiriMode::Keep => "Preserve the active config and print the bindings to add.",
            NiriMode::Replace => "Validate first, then plan a timestamped backup and replacement.",
        },
    );
    render_choice(
        frame,
        rows[1],
        state.integration_row == 1,
        "UMBRA",
        state.umbra().label(),
        match state.umbra() {
            UmbraMode::Off => "Do not expose the session lock or stage the greeter.",
            UmbraMode::Lock => "Verify a visual preview before enabling the secure lock binding.",
            UmbraMode::GreeterPreview => {
                "Stage display-manager greeter files without installing or activating them."
            }
        },
    );
    frame.render_widget(
        Paragraph::new("Up/Down selects a scope. Left/Right changes its value.")
            .style(Style::default().fg(MUTED))
            .alignment(Alignment::Center),
        rows[2],
    );
}

fn render_choice(
    frame: &mut ratatui::Frame,
    area: Rect,
    active: bool,
    label: &str,
    value: &str,
    detail: &str,
) {
    let marker = if active { "●" } else { "○" };
    let value_style = if active {
        Style::default().fg(ACCENT).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(MUTED)
    };
    frame.render_widget(
        Paragraph::new(vec![
            Line::from(vec![
                Span::styled(format!("{marker} {label}"), value_style),
                Span::styled(format!("    ←  {value}  →"), Style::default().fg(CYAN)),
            ]),
            Line::raw(""),
            Line::raw(detail),
        ])
        .block(Block::default().padding(Padding::uniform(1))),
        area,
    );
}

fn render_review(frame: &mut ratatui::Frame, area: Rect, state: &AppState, plan: &InstallPlan) {
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(36), Constraint::Percentage(64)])
        .split(area);
    let selected_count = plan
        .features
        .iter()
        .filter(|feature| feature.selected)
        .count();
    let missing_count = plan
        .features
        .iter()
        .filter(|feature| feature.selected)
        .flat_map(|feature| &feature.capabilities)
        .filter(|capability| !capability.available)
        .count();
    frame.render_widget(
        Paragraph::new(vec![
            Line::from(Span::styled(
                "MISSION SUMMARY",
                Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
            )),
            Line::raw(""),
            labelled("Profile", &plan.profile),
            labelled("Destination", &compact_home_path(plan)),
            labelled("Features", &selected_count.to_string()),
            labelled("Dependency gaps", &missing_count.to_string()),
            labelled("Niri", state.niri().label()),
            labelled("Umbra", state.umbra().label()),
            Line::raw(""),
            Line::from(Span::styled(
                "TRANSACTION READY // TYPE INSTALL NEXT",
                Style::default().fg(READY),
            )),
        ])
        .block(
            Block::default()
                .title(" REVIEW ")
                .borders(Borders::RIGHT)
                .padding(Padding::uniform(1)),
        ),
        columns[0],
    );

    let visible = columns[1].height.saturating_sub(2) as usize;
    let items = plan
        .operations
        .iter()
        .skip(state.review_offset)
        .take(visible)
        .map(|operation| {
            let (glyph, color) = operation_marker(operation.state);
            ListItem::new(vec![
                Line::from(vec![
                    Span::styled(format!("{glyph}  "), Style::default().fg(color)),
                    Span::styled(
                        &operation.summary,
                        Style::default().add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        if operation.requires_root {
                            "  sudo"
                        } else {
                            ""
                        },
                        Style::default().fg(WARN),
                    ),
                ]),
                Line::from(Span::styled(&operation.detail, Style::default().fg(MUTED))),
            ])
        })
        .collect::<Vec<_>>();
    frame.render_widget(
        List::new(items).block(
            Block::default()
                .title(" EXECUTION PLAN ")
                .padding(Padding::uniform(1)),
        ),
        columns[1],
    );
}

fn compact_home_path(plan: &InstallPlan) -> String {
    plan.install_root
        .strip_prefix(&plan.machine.home)
        .map(|relative| format!("~/{}", relative.display()))
        .unwrap_or_else(|_| plan.install_root.display().to_string())
}

fn render_footer(frame: &mut ratatui::Frame, area: Rect, state: &AppState) {
    let context = match state.screen {
        Screen::Profile => "↑/↓ choose profile",
        Screen::Integrations => "↑/↓ scope  ←/→ value",
        Screen::Review => "↑/↓ scroll plan",
        _ => "",
    };
    let primary = if state.screen == Screen::Review {
        ("ENTER", " install   ")
    } else {
        ("ENTER/TAB", " next   ")
    };
    let footer = Paragraph::new(Line::from(vec![
        key(primary.0),
        Span::raw(primary.1),
        key("BACKSPACE"),
        Span::raw(" back   "),
        key("Q"),
        Span::raw(" leave intact"),
        Span::styled(format!("    {context}"), Style::default().fg(MUTED)),
    ]))
    .wrap(Wrap { trim: true })
    .block(Block::default().borders(Borders::TOP));
    frame.render_widget(footer, area);
}

fn labelled(label: &str, value: &str) -> Line<'static> {
    Line::from(vec![
        Span::styled(format!("{label:<14}"), Style::default().fg(MUTED)),
        Span::raw(value.to_string()),
    ])
}

fn key(value: &str) -> Span<'_> {
    Span::styled(
        value,
        Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
    )
}

fn profile_description(profile: Profile) -> &'static str {
    match profile {
        Profile::Core => "Shell, audio, and user links only.",
        Profile::Recommended => "Daily desktop integrations without specialist extras.",
        Profile::Full => "Every supported feature, including build and portable tools.",
    }
}

fn feature_marker(status: FeatureStatus) -> (&'static str, Color) {
    match status {
        FeatureStatus::Ready => ("●", READY),
        FeatureStatus::Partial => ("◐", WARN),
        FeatureStatus::Missing => ("○", BAD),
        FeatureStatus::Skipped => ("·", MUTED),
    }
}

fn operation_marker(state: OperationState) -> (&'static str, Color) {
    match state {
        OperationState::Satisfied => ("✓", READY),
        OperationState::Planned => ("+", ACCENT),
        OperationState::Manual => ("!", WARN),
        OperationState::Conflict => ("?", BAD),
        OperationState::Skipped => ("−", MUTED),
        OperationState::Blocked => ("×", BAD),
    }
}

fn centered(area: Rect, max_width: u16, max_height: u16) -> Rect {
    let width = area.width.min(max_width);
    let height = area.height.min(max_height);
    let horizontal = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Length((area.width.saturating_sub(width)) / 2),
            Constraint::Length(width),
            Constraint::Min(0),
        ])
        .split(area);
    let vertical = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length((area.height.saturating_sub(height)) / 2),
            Constraint::Length(height),
            Constraint::Min(0),
        ])
        .split(horizontal[1]);
    vertical[1]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn screen_navigation_is_bounded() {
        let mut state = AppState::default();
        state.previous_screen();
        assert_eq!(state.screen, Screen::Welcome);
        for _ in 0..10 {
            state.next_screen();
        }
        assert_eq!(state.screen, Screen::Review);
    }

    #[test]
    fn selections_are_bounded() {
        assert_eq!(shifted(0, -1, 3), 0);
        assert_eq!(shifted(2, 1, 3), 2);
        assert_eq!(shifted(1, -1, 3), 0);
    }

    #[test]
    fn every_profile_has_copy() {
        for profile in Profile::ALL {
            assert!(!profile_description(profile).is_empty());
        }
    }
}
