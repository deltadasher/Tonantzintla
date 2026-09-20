.pragma library

// Keep messages as records; groups are a presentation of those records.
function groups(records) {
    const result = [], byKey = Object.create(null);
    records.forEach(function(record) {
        const key = record.critical ? record.groupKey + ':' + record.uid : record.groupKey;
        let group = byKey[key];
        if (!group) {
            group = Object.assign({}, record, {groupKey: key, members: []});
            byKey[key] = group;
            result.push(group);
        }
        group.members.push(record);
    });
    return result.map(function(group) {
        const members = group.members;
        delete group.members;
        group.uids = members.map(function(r) { return r.uid; });
        group.count = members.length;
        group.membersJson = JSON.stringify(members);
        return group;
    });
}
function append(records, entry, limit) {
    return [entry].concat(records.filter(function(r) { return r.uid !== entry.uid; })).slice(0, limit);
}
function remove(records, uids) {
    return records.filter(function(r) { return uids.indexOf(r.uid) < 0; });
}
