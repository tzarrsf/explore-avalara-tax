List<Product2> products = [
    SELECT Id, Name, Taxable__c, Tax_Class_Id__c
    FROM Product2
    WHERE Name NOT IN (
        'Shipping Charge Product',
        'USPS Ground',
        'MICA FL 1',
        'WOMEN\'S TORPEDO JACKET'
    )
];

for (Product2 p : products) {
    p.Taxable__c = true;
    p.Tax_Class_Id__c = 'PF051906';
}

update products;

System.debug(
    LoggingLevel.ERROR,
    '### Updated ' + products.size() + ' products with PF051906'
);