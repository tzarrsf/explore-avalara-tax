String storeName = 'B2B Store';
String username  = 'zarrthvader@b2b-impl-ready-august-26.org'; // ← TODO: Update this to the Buyer's username

// Find the buyer's Account.
User buyer = [
    SELECT Id,
           Username,
           ContactId,
           Contact.AccountId,
           Contact.Account.Name
    FROM User
    WHERE Username = :username
    LIMIT 1
];

if (buyer.ContactId == null || buyer.Contact.AccountId == null) {
    throw new IllegalArgumentException(
        'User has no Contact/Account: ' + username
    );
}

Id accountId = buyer.Contact.AccountId;

// Find the Web Store.
WebStore store = [
    SELECT Id, Name
    FROM WebStore
    WHERE Name = :storeName
    LIMIT 1
];

// Find the newest cart belonging to THIS account and store.
List<WebCart> carts = [
    SELECT Id,
           Name,
           AccountId,
           WebStoreId,
           WebStore.Name,
           Status,
           Type,
           CreatedDate,
           LastModifiedDate,
           TotalProductAmount,
           GrandTotalAmount
    FROM WebCart
    WHERE AccountId = :accountId
      AND WebStoreId = :store.Id
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];

if (carts.isEmpty()) {
    throw new IllegalArgumentException(
        'No cart found for Account=' + accountId +
        ' Store=' + store.Id
    );
}

WebCart cart = carts[0];

System.debug(
    'USER=' + username +
    ' | ACCOUNT=' + accountId +
    ' | STORE=' + store.Id +
    ' | CART=' + cart.Id +
    ' | STATUS=' + cart.Status
);

// Explicitly pass effectiveAccountId.
String path =
    '/services/data/v67.0/commerce/webstores/' +
    store.Id +
    '/carts/' +
    cart.Id +
    '/actions/evaluate-taxes' +
    '?effectiveAccountId=' +
    EncodingUtil.urlEncode(String.valueOf(accountId), 'UTF-8');

HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + path);
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');
req.setBody('{}');

HttpResponse res = new Http().send(req);

System.debug('STATUS: ' + res.getStatusCode());
System.debug('BODY:   ' + res.getBody());