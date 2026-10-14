from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NotificationTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("node"), "Node.js is not installed")
    def test_group_members_actions_retention_and_individual_dismissal(self):
        source = (ROOT / 'src/quickshell/services/NotificationModel.js').read_text().replace('.pragma library', '')
        script = source + '''
const assert = require('node:assert/strict');
const first = {uid:1, groupKey:'chat.desktop', summary:'first', body:'one', actions:[{identifier:'reply-1'}]};
const second = {uid:2, groupKey:'chat.desktop', summary:'second', body:'two', actions:[{identifier:'reply-2'}]};
let records = append(append([], first, 100), second, 100);
let group = groups(records)[0];
assert.equal(group.count, 2);
for (const groupKey of ['__proto__','constructor','toString']) {
    assert.equal(groups([{...first,groupKey}])[0].count,1);
}
assert.deepEqual(JSON.parse(group.membersJson).map(r=>r.body), ['two','one']);
assert.equal(JSON.parse(group.membersJson)[1].actions[0].identifier, 'reply-1');
records = remove(records, [2]);
assert.equal(groups(records)[0].summary, 'first');
assert.equal(groups(append(records,{...second,critical:true},100)).length,2);
assert.equal(groups(append(records,{...second,groupKey:'other.desktop'},100)).length,2);
for (let uid=3; uid<140; uid++) records=append(records,{...first,uid},100);
assert.equal(records.length,100);
assert.equal(records[99].uid,40);
assert.equal(remove(records,records.map(r=>r.uid)).length,0);
'''
        subprocess.run(['node', '-e', script], check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
