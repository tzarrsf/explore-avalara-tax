User u = [
    SELECT Id, Username, Name, Profile.Name, Profile.UserLicense.Name
    FROM User
    WHERE Id = :UserInfo.getUserId()
    LIMIT 1
];

System.debug('User Id: ' + u.Id + ' | Username: ' + u.Username + ' | Name: ' + u.Name);

if (u.Profile.Name != 'System Administrator') {
    System.debug('Error: Executing user is not a System Administrator. Current profile: ' + u.Profile.Name);
    return;
}

PermissionSet targetPermissionSet = new PermissionSet(
    Name = 'Avalara_Tax_Store_Custom_Fields',
    Label = 'Avalara Tax Store Custom Fields'
);

List<PermissionSet> permissionSets = [
    SELECT Id, Name, Label, NamespacePrefix, License.Name
    FROM PermissionSet
    WHERE Name = :targetPermissionSet.Name
];

System.debug('Found Permission Sets: ' + permissionSets.size());

if (permissionSets.isEmpty()) {
    System.debug(
        'Error: Permission set not found. API Name: "' +
        targetPermissionSet.Name +
        '", Label: "' +
        targetPermissionSet.Label +
        '".'
    );
    return;
}

Set<Id> assignedPermissionSetIds = new Set<Id>();
for (PermissionSetAssignment psa : [
    SELECT PermissionSetId
    FROM PermissionSetAssignment
    WHERE AssigneeId = :u.Id
]) {
    assignedPermissionSetIds.add(psa.PermissionSetId);
}

List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();

for (PermissionSet ps : permissionSets) {
    String requiredLicenseName = ps.License == null ? null : ps.License.Name;

    System.debug(
        'Permission Set Id: ' + ps.Id +
        ' | Name: ' + ps.Name +
        ' | Label: ' + ps.Label +
        ' | Namespace: ' + ps.NamespacePrefix +
        ' | Required License: ' + requiredLicenseName
    );

    if (requiredLicenseName != null && requiredLicenseName != u.Profile.UserLicense.Name) {
        System.debug(
            'Error: Permission set requires license "' + requiredLicenseName +
            '", but executing user has license "' + u.Profile.UserLicense.Name + '".'
        );
        return;
    }

    if (!assignedPermissionSetIds.contains(ps.Id)) {
        toInsert.add(new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = ps.Id
        ));
    }
}

if (!toInsert.isEmpty()) {
    try {
        insert toInsert;
        System.debug('Inserted ' + toInsert.size() + ' permission set assignment(s).');
    } catch (DmlException e) {
        System.debug(
            'Error: Salesforce rejected the permission set assignment. Details: ' +
            e.getDmlMessage(0)
        );
    }
} else {
    System.debug('No new permission set assignments needed.');
}