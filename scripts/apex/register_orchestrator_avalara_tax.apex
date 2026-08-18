ApexClass orchestratorClass = [
    SELECT Id, Name
    FROM ApexClass
    WHERE Name = 'LwrCca_CartOrchestratorTaxAvalara'
    LIMIT 1
];

RegisteredExternalService service = new RegisteredExternalService(
    DeveloperName = 'CartOrchestratorTaxAvalara',
    MasterLabel = 'CartOrchestratorTaxAvalara',
    ExtensionPointName = 'Commerce_Domain_Cart_Calculate',
    ExternalServiceProviderId = orchestratorClass.Id,
    ExternalServiceProviderType = 'Extension'
);

insert service;

System.debug('Created RegisteredExternalService: ' + service.Id);