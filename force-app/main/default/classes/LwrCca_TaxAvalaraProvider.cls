/**
 * @description       : Concrete provider fulfilling the LwrCca_TaxAbstractProvider template requirements.
 * @author            : Code-It-Forward team members (main contributors) and Tom Zarr (content adaptation and editing for course)
 *                      To find out more about Code-It-Forward please consult these links:
 *                      https://sfdc.co/CodeItForwardCharter
 *                      https://sfdc.co/CodeItForwardRepository
 *                      https://sfdc.co/CodeItForwardRegistration
 * @group             : Salesforce Commerce Partner Enablement Success
 * @last modified on  : 07-01-2026
 * @last modified by  : Tom Zarr
**/

public without sharing class LwrCca_TaxAvalaraProvider extends LwrCca_TaxAbstractProvider
{

    public LwrCca_TaxAvalaraProvider() {}

    public override void prepareCreateTransaction(LwrCca_TaxProviderRequest taxRequest,Map<String, String> callOutRequest)
    {
        Boolean hasMultipleShipments = taxRequest.hasMultipleShipments != null && taxRequest.hasMultipleShipments == true ? true: false;

        LwrCca_TaxAvalaraRequest avalaraRequest = new LwrCca_TaxAvalaraRequest();
        avalaraRequest.type = taxRequest.taxTransacionType;
        avalaraRequest.currencyCode = taxRequest.currencyCode;
        avalaraRequest.commit_Z = taxRequest.taxMetaData.isCommit;
        // if (
        //   String.isNotBlank(avalaraRequest.type) &&
        //   avalaraRequest.type.contains('Invoice')
        // ) {
        //   avalaraRequest.commit_Z = true;
        // }else{
        //   avalaraRequest.commit_Z = false;
        // }

        if (String.isNotBlank(taxRequest.taxMetaData.companyCode))
        {
            avalaraRequest.companyCode = taxRequest.taxMetaData.companyCode;
        }

        if (String.isNotBlank(taxRequest.taxMetaData.customerCode))
        {
            avalaraRequest.customerCode = taxRequest.taxMetaData.customerCode;
        }

        if (String.isNotBlank(taxRequest.customerTaxId))
        {
            avalaraRequest.businessIdentificationNo = taxRequest.customerTaxId;
        }

        if (String.isNotBlank(taxRequest.customerExemptionCode))
        {
            avalaraRequest.exemptionNo = taxRequest.customerExemptionCode;
        }

        if (String.isNotBlank(taxRequest.entityUseCode))
        {
            avalaraRequest.entityUseCode = taxRequest.entityUseCode;
        }

        avalaraRequest.date_Z = System.now() + '';
        //taxRequest.taxableCartItems = null;
        
		System.debug(
			LoggingLevel.ERROR,
			'### PREPARE CREATE BRANCH'
			+ ' | taxableCartItems='
			+ (taxRequest.taxableCartItems == null
				? 'NULL'
				: String.valueOf(taxRequest.taxableCartItems))
			+ ' | size='
			+ (taxRequest.taxableCartItems == null
				? 'NULL'
				: String.valueOf(taxRequest.taxableCartItems.size()))
		);
		
		System.debug(
			LoggingLevel.ERROR,
			'### PREVIOUS AVALARA REQUEST OBJECT='
			+ JSON.serialize(avalaraRequest)
		);

		if (taxRequest.taxableCartItems != null &&  taxRequest.taxableCartItems.keySet().size() > 0 )
        {
        	System.debug(LoggingLevel.ERROR, '### USING prepareRequestFromExistingData');
			avalaraRequest.lines = prepareRequestFromExistingData(taxRequest, hasMultipleShipments);
        }
        else
        {
            System.debug(LoggingLevel.ERROR, '### USING prepareRequestFromDB');
			avalaraRequest.lines = prepareRequestFromDB(taxRequest, hasMultipleShipments);
        }

		System.debug(
			LoggingLevel.ERROR,
			'### FINAL AVALARA REQUEST OBJECT='
			+ JSON.serialize(avalaraRequest)
		);

        if (!hasMultipleShipments)
        {
            LwrCca_TaxAvalaraRequest.Addresses addresses = new LwrCca_TaxAvalaraRequest.Addresses();
            addresses.shipFrom = prepareShipFromAddress(taxRequest);
            addresses.shipTo = prepareShipToAddress(
                taxRequest.street,
                taxRequest.city,
                taxRequest.state,
                taxRequest.postalCode,
                taxRequest.country
            );
            avalaraRequest.addresses = addresses;
        }

		System.debug(
			LoggingLevel.ERROR,
			'### AVALARA OUTBOUND LINE'
			+ ' | number=' + (avalaraRequest.lines != null && avalaraRequest.lines.size() > 0
				? String.valueOf(avalaraRequest.lines[0].number_Z)
				: 'NONE')
			+ ' | itemCode=' + (avalaraRequest.lines != null && avalaraRequest.lines.size() > 0
				? avalaraRequest.lines[0].itemCode
				: 'NONE')
			+ ' | taxCode=' + (avalaraRequest.lines != null && avalaraRequest.lines.size() > 0
				? avalaraRequest.lines[0].taxCode
				: 'NONE')
			+ ' | amount=' + (avalaraRequest.lines != null && avalaraRequest.lines.size() > 0
				? String.valueOf(avalaraRequest.lines[0].amount)
				: 'NONE')
		);

        String avalaraRequestBody = JSON.serialize(avalaraRequest, true);

		System.debug(
			LoggingLevel.ERROR,
			'### ACTUAL AVALARA REQUEST >>> ' +
			JSON.serialize(avalaraRequest)
		);

        avalaraRequestBody = avalaraRequestBody.replaceAll('_Z', '');
		System.debug(
			LoggingLevel.ERROR,
			'### FINAL AVALARA REQUEST BODY='
			+ avalaraRequestBody
		);
        callOutRequest.put(Constants.SERVICE_REQUEST_BODY, avalaraRequestBody);
        System.debug('====== avalaraRequest : '+avalaraRequestBody);
    }

    public virtual override LwrCca_TaxProviderResponse getTaxFromResponse( String strAvalaraResponseBody, LwrCca_TaxProviderRequest tpRequest)
    {
        LwrCca_TaxProviderResponse tpResponse = new LwrCca_TaxProviderResponse();
        Map<String, LwrCca_LineItemTaxDetails> taxes = new Map<String, LwrCca_LineItemTaxDetails>();
        Map<String, LwrCca_TaxableCartItem> taxableCartItems = tpRequest.taxableCartItems;

        LwrCca_TaxProviderResponse shippingResponse;
        System.debug('====== strAvalaraResponseBody : '+strAvalaraResponseBody);
        if (String.isNotBlank(strAvalaraResponseBody)) {
            LwrCca_TaxAvalaraResponse avalaraTaxResponse = LwrCca_TaxAvalaraResponse.parse(strAvalaraResponseBody);

            if ( avalaraTaxResponse.lines != null && avalaraTaxResponse.lines.size() > 0 )
            {
                for (LwrCca_TaxAvalaraResponse.Lines line : avalaraTaxResponse.lines)
                {
                    String lineNumber = line.lineNumber;
                    LwrCca_LineItemTaxDetails liTaxDetails = new LwrCca_LineItemTaxDetails();
                    liTaxDetails.tax = 0;
                    liTaxDetails.rate = 0;

                    if (line.tax > 0)
                    {
                            liTaxDetails.tax = line.tax;
                    }

                    if (line.taxableAmount > 0) {
                        liTaxDetails.rate = liTaxDetails.tax / line.taxableAmount;
                    }

					if (!Test.isRunningTest()) {
						LwrCca_TaxableCartItem cartItem;
						String matchedCartItemKey;

						// First try Avalara lineNumber as a direct key.
						if (taxableCartItems.containsKey(lineNumber)) {
							matchedCartItemKey = lineNumber;
							cartItem = taxableCartItems.get(lineNumber);
						}

						// Avalara lineNumber is not our Salesforce CartItem Id.
						// Fall back to itemCode/SKU, BUT preserve the original map key.
						if (cartItem == null) {
							for (String cartItemKey : taxableCartItems.keySet()) {
								LwrCca_TaxableCartItem candidate =
									taxableCartItems.get(cartItemKey);

								if (candidate != null && candidate.sku == line.itemCode) {
									matchedCartItemKey = cartItemKey;
									cartItem = candidate;
									break;
								}
							}
						}

						if (cartItem != null) {
							 cartItem.lineItemTexas.add(liTaxDetails);

							System.debug(
								LoggingLevel.ERROR,
								'### AVALARA MAP SUCCESS'
								+ ' | lineNumber=' + lineNumber
								+ ' | itemCode=' + line.itemCode
								+ ' | Salesforce key=' + matchedCartItemKey
								+ ' | tcItem.id=' + cartItem.id
							);
						} else {
							System.debug(
								LoggingLevel.ERROR,
								'### AVALARA MAP FAILED'
								+ ' | lineNumber=' + lineNumber
								+ ' | itemCode=' + line.itemCode
								+ ' | available keys=' + taxableCartItems.keySet()
							);
						}
					}
                }
                tpResponse.taxableCartItems = taxableCartItems;
            }
        }

        return tpResponse;
    }

    private List<LwrCca_TaxAvalaraRequest.Lines> prepareRequestFromExistingData(LwrCca_TaxProviderRequest taxRequest, Boolean hasMultipleShipments)
    {
        List<LwrCca_TaxAvalaraRequest.Lines> lines = new List<LwrCca_TaxAvalaraRequest.Lines>();

        for (String id : taxRequest.taxableCartItems.keySet())
        {
            LwrCca_TaxableCartItem cartItem = taxRequest.taxableCartItems.get(id);

			if (cartItem.id == null) {
				cartItem.id = id;
			}

			System.debug(
				LoggingLevel.ERROR,
				'### PREPARE AVALARA LINE'
				+ ' | id=' + cartItem.id
				+ ' | sku=' + cartItem.sku
				+ ' | amount=' + cartItem.amount
				+ ' | taxClassId=[' + cartItem.taxClassId + ']'
				+ ' | taxClassIdBlank=' + String.isBlank(cartItem.taxClassId)
			);

			System.debug(
				LoggingLevel.ERROR,
				'### CART ITEM BEFORE PREPARE LINE'
				+ ' | id=' + cartItem.id
				+ ' | sku=' + cartItem.sku
				+ ' | amount=' + cartItem.amount
				+ ' | taxClassId=' + cartItem.taxClassId
				+ ' | lineItemType=' + cartItem.lineItemType
			);

            LwrCca_TaxAvalaraRequest.Lines line = prepareLine(
                cartItem.id,
                cartItem.sku,
                cartItem.amount,
                cartItem.lineItemType,
                cartItem.taxClassId,
				cartItem.productExemptionCode,
				cartItem.entityUseCode,
				taxRequest,
                false
            );

			System.debug(
				LoggingLevel.ERROR,
				'### ACTUAL AVALARA LINE OBJECT'
				+ ' | number_Z=' + line.number_Z
				+ ' | itemCode=' + line.itemCode
				+ ' | amount=' + line.amount
				+ ' | taxCode=' + line.taxCode
				+ ' | exemptionCode=' + line.exemptionCode
				+ ' | entityUseCode=' + line.entityUseCode
				+ ' | taxIncluded=' + line.taxIncluded
			);

			System.debug(
				LoggingLevel.ERROR,
				'### AVALARA OUTBOUND LINE'
				+ ' | id=' + cartItem.id
				+ ' | sku=' + cartItem.sku
				+ ' | taxClassId=' + cartItem.taxClassId
				+ ' | line.taxCode=' + line.taxCode
				+ ' | line.amount=' + line.amount
			);

            if (hasMultipleShipments)
            {
                LwrCca_TaxAvalaraRequest.Addresses addresses = new LwrCca_TaxAvalaraRequest.Addresses();
                addresses.shipFrom = prepareShipFromAddress(taxRequest);
                addresses.shipTo = prepareShipToAddress(
                cartItem.street,
                cartItem.city,
                cartItem.state,
                cartItem.postalCode,
                cartItem.country
                );
                line.addresses = addresses;
            }

            lines.add(line);
        }

        return lines;
    }

    private List<LwrCca_TaxAvalaraRequest.Lines> prepareRequestFromDB(LwrCca_TaxProviderRequest taxRequest, Boolean hasMultipleShipments)
    {

            String cartId = taxRequest.cartId;
            taxRequest.taxableCartItems = new Map<String, LwrCca_TaxableCartItem>();
            List<LwrCca_TaxAvalaraRequest.Lines> lines = new List<LwrCca_TaxAvalaraRequest.Lines>();
            String query = 'SELECT Id, Sku, TotalLineAmount, Quantity, Type,Product2Id,Name,Product2.Family, Product2.StockKeepingUnit';

            if (hasMultipleShipments)
            {
                query += ',CartDeliveryGroup.Id,CartDeliveryGroup.DeliverToStreet,CartDeliveryGroup.DeliverToCity,CartDeliveryGroup.DeliverToState,CartDeliveryGroup.DeliverToPostalCode,CartDeliveryGroup.DeliverToCountry';
            }

            if(taxRequest.taxMetaData.useProductTaxCodes)
            {
                query += ',Product2.Tax_Class_Id__c';
            }

            if(taxRequest.taxMetaData.productTaxExemption)
            {
                query += ',Product2.Taxable__c,Product2.Entity_Use_Code__c,Product2.Exemption_Code__c';
            }

            query += ' FROM CartItem WHERE  cartId=:cartId';

            if (!taxRequest.taxMetaData.shippingItemsTaxable)
            {
                query += ' AND Type = \'Product\'';
            }

            for (CartItem cartItem : Database.query(query))
            {	
				
				LwrCca_TaxAvalaraRequest.Lines line = prepareLine(
                    cartItem.Id,
                    cartItem.SKU !=null ? cartItem.SKU : cartItem.Product2.StockKeepingUnit,
                    cartItem.TotalLineAmount,
                    cartItem.Type,
                    taxRequest.taxMetaData.useProductTaxCodes && cartItem.Product2.Tax_Class_Id__c !=null ? cartItem.Product2.Tax_Class_Id__c : null,
                    taxRequest.taxMetaData.productTaxExemption ? cartItem.Product2.Exemption_Code__c : null,
                    taxRequest.taxMetaData.productTaxExemption ? cartItem.Product2.Entity_Use_Code__c : null,
                    taxRequest,
                    true
                );

				System.debug(
					LoggingLevel.ERROR,
					'### ACTUAL AVALARA LINE OBJECT'
					+ ' | number_Z=' + line.number_Z
					+ ' | itemCode=' + line.itemCode
					+ ' | amount=' + line.amount
					+ ' | taxCode=' + line.taxCode
					+ ' | exemptionCode=' + line.exemptionCode
					+ ' | entityUseCode=' + line.entityUseCode
					+ ' | taxIncluded=' + line.taxIncluded
				);

                if (hasMultipleShipments)
                {
                    LwrCca_TaxAvalaraRequest.Addresses addresses = new LwrCca_TaxAvalaraRequest.Addresses();
                    addresses.shipFrom = prepareShipFromAddress(taxRequest);
                    addresses.shipTo = prepareShipToAddress(
                    cartItem.CartDeliveryGroup.DeliverToStreet,
                    cartItem.CartDeliveryGroup.DeliverToCity,
                    cartItem.CartDeliveryGroup.DeliverToState,
                    cartItem.CartDeliveryGroup.DeliverToPostalCode,
                    cartItem.CartDeliveryGroup.DeliverToCountry
                    );
                    line.addresses = addresses;
                }

                lines.add(line);
            }

            return lines;
    }

    private LwrCca_TaxAvalaraRequest.Lines prepareLine(
        ID id,
        String sku,
        Decimal taxableAmount,
        String type,
        String taxClassId,
        String exemptionCode,
        String entityUseCode,
        LwrCca_TaxProviderRequest taxRequest,
        Boolean setInRequestToo
    )
    {
        System.debug(
			LoggingLevel.ERROR,
			'### PREPARELINE DEFINITELY EXECUTED'
			+ ' | id=' + id
			+ ' | sku=' + sku
			+ ' | taxClassId=' + taxClassId
			+ ' | setInRequestToo=' + setInRequestToo
		);
		
		LwrCca_TaxAvalaraRequest.Lines line = new LwrCca_TaxAvalaraRequest.Lines();
        line.number_Z = id;
        line.itemCode = sku;
        line.amount = taxableAmount;

        if (String.isNotBlank(taxRequest.taxMetaData.taxationPolicy))
        {
            line.taxIncluded = taxRequest.taxMetaData.taxationPolicy.equalsIgnoreCase( 'net' ) ? false : true;
        }

		System.debug(
			LoggingLevel.ERROR,
			'ZZZZZZ TAXCODE BEFORE AVALARA ZZZZZZ'
			+ ' | id=' + id
			+ ' | sku=' + sku
			+ ' | taxClassId=' + taxClassId
		);

        line.taxCode = taxClassId;
        line.exemptionCode = exemptionCode;
        line.entityUseCode = entityUseCode;

		 System.debug(
			LoggingLevel.ERROR,
			'### PREPARELINE RESULT'
			+ ' | number=' + line.number_Z
			+ ' | itemCode=' + line.itemCode
			+ ' | taxCode=' + line.taxCode
		);

        if (setInRequestToo)
        {
            LwrCca_TaxableCartItem tcItem = new LwrCca_TaxableCartItem();
            tcItem.id = id;
            tcItem.amount = taxableAmount;
            tcItem.sku = sku;
            tcItem.lineItemType = type;
            taxRequest.taxableCartItems.put(id, tcItem);
        }

        return line;
    }

    public override void prepareCommitTransaction(LwrCca_TaxProviderRequest taxRequest, Map<String, String> callOutRequest)
    {

    }

    LwrCca_TaxAvalaraRequest.ShipFrom prepareShipFromAddress(LwrCca_TaxProviderRequest taxRequest)
    {
        LwrCca_TaxAvalaraRequest.ShipFrom address = new LwrCca_TaxAvalaraRequest.ShipFrom();
        address.line1 = taxRequest.taxMetaData.shipFromLine1;
        address.city = taxRequest.taxMetaData.shipFromCity;
        address.region = taxRequest.taxMetaData.shipFromState;
        address.postalCode = taxRequest.taxMetaData.shipFromZipCode;
        address.country = taxRequest.taxMetaData.shipFromCountry;
        return address;
    }

    LwrCca_TaxAvalaraRequest.ShipFrom prepareShipToAddress(String street, String city, String state, String postalCode, String country)
    {
        LwrCca_TaxAvalaraRequest.ShipFrom address = new LwrCca_TaxAvalaraRequest.ShipFrom();
        address.line1 = street;
        address.city = city;
        address.region = state;
        address.postalCode = postalCode;
        address.country = country;
        return address;
    }
}