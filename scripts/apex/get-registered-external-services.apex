List<RegisteredExternalService> services = [
    SELECT Id,
           DeveloperName,
           ExternalServiceProviderType,
           ExternalServiceProviderId
    FROM RegisteredExternalService
    ORDER BY ExternalServiceProviderType, DeveloperName
];

Set<Id> providerIds = new Set<Id>();

for (RegisteredExternalService service : services) {
    if (service.ExternalServiceProviderId != null) {
        providerIds.add(service.ExternalServiceProviderId);
    }
}

Map<Id, ApexClass> classesById = new Map<Id, ApexClass>();

if (!providerIds.isEmpty()) {
    for (ApexClass cls : [
        SELECT Id, Name, NamespacePrefix
        FROM ApexClass
        WHERE Id IN :providerIds
    ]) {
        classesById.put(cls.Id, cls);
    }
}

System.debug('========== REGISTERED EXTERNAL SERVICES ==========');

for (RegisteredExternalService service : services) {

    ApexClass cls = classesById.get(service.ExternalServiceProviderId);

    String className = cls == null
        ? 'NOT AN APEX CLASS / NOT FOUND'
        : (
            String.isBlank(cls.NamespacePrefix)
                ? cls.Name
                : cls.NamespacePrefix + '.' + cls.Name
        );

    System.debug(
        'TYPE=' + service.ExternalServiceProviderType +
        ' | SERVICE=' + service.DeveloperName +
        ' | PROVIDER ID=' + service.ExternalServiceProviderId +
        ' | CLASS=' + className
    );
}

System.debug('==================================================');