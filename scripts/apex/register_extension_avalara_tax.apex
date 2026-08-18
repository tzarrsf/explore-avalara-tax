ApexClass taxClass = [
    SELECT Id, Name
    FROM ApexClass
    WHERE Name = 'LwrCca_TaxCartCalculatorExtension'
    LIMIT 1
];

RegisteredExternalService service = new RegisteredExternalService();
service.DeveloperName = 'TaxAvalara';
service.MasterLabel = 'TaxAvalara';
service.ExtensionPointName = 'Commerce_Domain_Tax_CartCalculator';
service.ExternalServiceProviderId = taxClass.Id;
service.ExternalServiceProviderType = 'Extension';

insert service;

System.debug('Created RegisteredExternalService: ' + service.Id);