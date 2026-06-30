// Store to update
String storeName = 'B2B Store';

// New values
String taxDocumentType = 'SalesOrder';
String taxTransactionType = 'CreateTransaction';

// Find the store
List<WebStore> stores = [
    SELECT Id,
           Name,
           Tax_Document_Type__c,
           Tax_Transaction_Type__c
    FROM WebStore
    WHERE Name = :storeName
    LIMIT 1
];

if (stores.isEmpty()) {
    System.debug('ERROR: No WebStore found with name "' + storeName + '".');
} else {
    WebStore store = stores[0];

    System.debug('Found store "' + store.Name + '" (Id=' + store.Id + ').');
    System.debug('Current Tax_Document_Type__c = ' + store.Tax_Document_Type__c);
    System.debug('Current Tax_Transaction_Type__c = ' + store.Tax_Transaction_Type__c);

    store.Tax_Document_Type__c = taxDocumentType;
    store.Tax_Transaction_Type__c = taxTransactionType;

    update store;

    System.debug('SUCCESS: Updated store "' + store.Name + '".');
    System.debug('New Tax_Document_Type__c = ' + store.Tax_Document_Type__c);
    System.debug('New Tax_Transaction_Type__c = ' + store.Tax_Transaction_Type__c);
}