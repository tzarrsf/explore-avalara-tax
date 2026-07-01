/**
 * @description       : Data transport / Anemic object representing the required response messaging for the response after the tax
 *                      provider has received the request and processed it. Supports the LwrCca_TaxAbstractProvider and concrete
 *                      implementation descendants.
 * @author            : Code-It-Forward team members (main contributors) and Tom Zarr (content adaptation and editing for course)
 *                      To find out more about Code-It-Forward please consult these links:
 *                      https://sfdc.co/CodeItForwardCharter
 *                      https://sfdc.co/CodeItForwardRepository
 *                      https://sfdc.co/CodeItForwardRegistration
 * @group             : Salesforce Commerce Partner Enablement Success
 * @last modified on  : 07-01-2026
 * @last modified by  : Tom Zarr
**/
public with sharing class LwrCca_TaxProviderResponse
{
    public LwrCca_TaxProviderResponse() {}

    public Map<String, LwrCca_TaxableCartItem> taxableCartItems { get; set; }
}