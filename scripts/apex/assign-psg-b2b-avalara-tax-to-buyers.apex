// Initialize the list of target users up front
List<SObject> targetUsers = new List<SObject>();

// Seed targetUsers with Buyer User(s)
List<User> buyerUsers = [
    SELECT Id, Username, Name
    FROM User
    WHERE Name LIKE '%Guest Buyer%'
];

targetUsers.addAll(buyerUsers);
System.debug('Seeded targetUsers with ' + buyerUsers.size() + ' Buyer User record(s).');

// Find the Permission Set Group safely
List<PermissionSetGroup> psgList = [
    SELECT Id, DeveloperName, MasterLabel
    FROM PermissionSetGroup
    WHERE MasterLabel = 'Avalara Tax Store Custom Fields PSG'
    LIMIT 1
];

if (psgList.isEmpty()) {
    System.debug('ERROR: Permission Set Group not found. Exiting.');
} else {
    PermissionSetGroup psg = psgList[0];

    System.debug('Found Permission Set Group: "' + psg.MasterLabel + '" ' +
                 '(DeveloperName=' + psg.DeveloperName + ', Id=' + psg.Id + ').');

    // Permission set labels to use as the source of users
    Set<String> sourcePermissionSetLabels = new Set<String>{
        'B2B Buyer',
        'B2B Enhanced Buyer',
        'Buyer Manager'
    };

    // Find the permission sets by label
    List<PermissionSet> sourcePermissionSets = [
        SELECT Id, Label, Name
        FROM PermissionSet
        WHERE Label IN :sourcePermissionSetLabels
    ];

    if (sourcePermissionSets.isEmpty()) {
        System.debug('ERROR: No matching source permission sets were found. Exiting.');
    } else {
        System.debug('Found ' + sourcePermissionSets.size() + ' source permission set(s).');

        // Collect the permission set ids
        Set<Id> sourcePermissionSetIds = new Set<Id>();
        for (PermissionSet ps : sourcePermissionSets) {
            sourcePermissionSetIds.add(ps.Id);
            System.debug('Source Permission Set: "' + ps.Label +
                         '" (Name=' + ps.Name + ', Id=' + ps.Id + ').');
        }

        // Add the users assigned to those permission sets
        List<User> sourceUsers = [
            SELECT Id, Username, Name
            FROM User
            WHERE Id IN (
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetId IN :sourcePermissionSetIds
            )
        ];

        targetUsers.addAll(sourceUsers);

        System.debug('Added ' + sourceUsers.size() +
                     ' user(s) from the source permission sets.');
        System.debug('targetUsers now contains ' + targetUsers.size() +
                     ' record(s) before dedupe.');

        // Deduplicate users by Id
        Map<Id, User> uniqueTargetUsers = new Map<Id, User>();
        for (SObject sob : targetUsers) {
            User u = (User)sob;
            uniqueTargetUsers.put(u.Id, u);
        }

        System.debug('Unique target users to process: ' + uniqueTargetUsers.size() + '.');

        if (uniqueTargetUsers.isEmpty()) {
            System.debug('No users to process. Exiting.');
        } else {
            // Find any users already assigned to the PSG so we do not duplicate inserts
            Set<Id> alreadyAssignedUserIds = new Set<Id>();
            for (PermissionSetAssignment existingPsa : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE AssigneeId IN :uniqueTargetUsers.keySet()
                AND PermissionSetGroupId = :psg.Id
            ]) {
                alreadyAssignedUserIds.add(existingPsa.AssigneeId);
            }

            System.debug('Users already assigned to "' + psg.MasterLabel + '": ' +
                         alreadyAssignedUserIds.size() + '.');

            Integer assignedCount = 0;
            Integer skippedCount = 0;

            for (User u : uniqueTargetUsers.values()) {
                System.debug('Processing user: "' + u.Name +
                             '" (Username=' + u.Username +
                             ', Id=' + u.Id + ').');

                if (!alreadyAssignedUserIds.contains(u.Id)) {
                    insert new PermissionSetAssignment(
                        AssigneeId = u.Id,
                        PermissionSetGroupId = psg.Id
                    );

                    assignedCount++;
                    System.debug('Assigned user "' + u.Name +
                                 '" to Permission Set Group "' + psg.MasterLabel + '".');
                } else {
                    skippedCount++;
                    System.debug('Skipped user "' + u.Name +
                                 '" because they already have Permission Set Group "' +
                                 psg.MasterLabel + '".');
                }
            }

            System.debug('Finished processing users. Assigned=' + assignedCount +
                         ', Skipped=' + skippedCount +
                         ', Total Unique Users=' + uniqueTargetUsers.size() + '.');
        }
    }
}