WebStore ws = [
    SELECT Id,
           Name,
           Description,
           Tax_Document_Type__c,
           Tax_Transaction_Type__c
    FROM WebStore
    WHERE Name = 'B2B Store'
    LIMIT 1
];

System.debug('Id: ' + ws.Id);
System.debug('Name: ' + ws.Name);
System.debug('Description: ' + ws.Description);
System.debug('Tax_Document_Type__c: ' + ws.Tax_Document_Type__c);
System.debug('Tax_Transaction_Type__c: ' + ws.Tax_Transaction_Type__c);