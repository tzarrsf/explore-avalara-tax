// Get all field API names for WebStore
Map<String, Schema.SObjectField> fields =
    Schema.SObjectType.WebStore.fields.getMap();

List<String> fieldNames = new List<String>(fields.keySet());
fieldNames.sort();

// Build dynamic SOQL
String soql =
    'SELECT ' + String.join(fieldNames, ',') +
    ' FROM WebStore WHERE Name = \'B2B Store\' LIMIT 1';

WebStore ws = Database.query(soql);

// Print every field/value
for (String fieldName : fieldNames) {
    System.debug(fieldName + ' = ' + ws.get(fieldName));
}