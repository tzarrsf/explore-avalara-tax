/**
 * @description       : Tax cart calculator extension for Commerce carts.
 * @author            : Code-It-Forward team members (main contributors) and Tom Zarr
 *                      (content adaptation and editing for course)
 *                      To find out more about Code-It-Forward please consult these links:
 *                      https://sfdc.co/CodeItForwardCharter
 *                      https://sfdc.co/CodeItForwardRepository
 *                      https://sfdc.co/CodeItForwardRegistration
 * @group             : Salesforce Commerce Partner Enablement Success
 * @last modified on  : 08-18-2026
 * @last modified by  : Tom Zarr
 **/
global without sharing class LwrCca_TaxCartCalculatorExtension
    extends CartExtension.TaxCartCalculator {

    global LwrCca_TaxCartCalculatorExtension() {}

    /**
     * Main cart tax calculation entry point.
     */
    public virtual override void calculate(
        CartExtension.CartCalculateCalculatorRequest request
    ) {
        try {
            CartExtension.Cart cart = request.getCart();

            existingCartValidationMessageCleanUp(cart);
            existingCartTaxesCleanUp(cart);

            LwrCca_TaxMetaData taxMetaData = getMetaData(
                cart.getWebstoreId(),
                '',
                ''
            );

            if (taxMetaData == null) {
                System.debug(
                    LoggingLevel.ERROR,
                    '### No Tax_Provider__mdt configuration found. Skipping tax calculation.'
                );
                return;
            }

            System.debug(
                LoggingLevel.ERROR,
                '### TAX CALC CONFIG'
                + ' | webStoreId=' + cart.getWebstoreId()
                + ' | useProductTaxCodes=' + taxMetaData.useProductTaxCodes
                + ' | productTaxExemption=' + taxMetaData.productTaxExemption
                + ' | customerTaxExemption=' + taxMetaData.customerTaxExemption
                + ' | defaultProductTaxCode=' + taxMetaData.defaultProductTaxCode
                + ' | defaultShippingTaxCode=' + taxMetaData.defaultShippingTaxCode
                + ' | shippingItemsTaxable=' + taxMetaData.shippingItemsTaxable
            );

            LwrCca_TaxProviderRequest taxProviderRequest =
                createTaxRequest(cart, taxMetaData);

            System.debug(
                LoggingLevel.ERROR,
                '### TAX REQUEST ITEMS='
                + JSON.serialize(taxProviderRequest.taxableCartItems)
            );

            if (taxMetaData.customerTaxExemption) {
                setExemptionDetails(
                    taxProviderRequest,
                    taxMetaData
                );
            }

            LwrCca_TaxAbstractProvider tProvider =
                LwrCca_TaxProviderFactory.getTaxProvider(taxMetaData);

            if (tProvider != null) {
                LwrCca_TaxProviderResponse tpResponse =
                    tProvider.calculateTax(taxProviderRequest);

                if (!Test.isRunningTest()) {
                    if (tpResponse == null) {
                        System.debug(
                            LoggingLevel.ERROR,
                            '### Tax provider returned null. Skipping setTaxInCart().'
                        );
                        return;
                    }

                    setTaxInCart(
                        cart,
                        taxMetaData,
                        tpResponse
                    );
                }
            } else {
                System.debug(
                    LoggingLevel.ERROR,
                    '### No tax provider returned from factory. Skipping tax calculation.'
                );
            }

        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '### calculate() exception: '
                + e.getMessage()
                + '\n'
                + e.getStackTraceString()
            );

            if (Test.isRunningTest()) {
                throw e;
            }

            throw new CalloutException(
                'There was a problem with the request. Original error: '
                + e.getMessage()
            );
        }
    }

    /**
     * Removes existing taxes from cart items and price adjustments.
     */
    public virtual void existingCartTaxesCleanUp(
        CartExtension.Cart cart
    ) {
        CartExtension.CartItemList cartItemCollection =
            cart.getCartItems();

        for (
            Integer i = cartItemCollection.size() - 1;
            i >= 0;
            i--
        ) {
            CartExtension.CartItem cartItem =
                cartItemCollection.get(i);

            CartExtension.CartTaxList cartTaxes =
                cartItem.getCartTaxes();

            for (
                Integer j = cartTaxes.size() - 1;
                j >= 0;
                j--
            ) {
                cartTaxes.remove(
                    cartTaxes.get(j)
                );
            }

            CartExtension.CartItemPriceAdjustmentList priceAdjustments =
                cartItem.getCartItemPriceAdjustments();

            for (
                Integer k = priceAdjustments.size() - 1;
                k >= 0;
                k--
            ) {
                CartExtension.CartItemPriceAdjustment priceAdjustment =
                    priceAdjustments.get(k);

                CartExtension.CartTaxList adjustmentTaxes =
                    priceAdjustment.getCartTaxes();

                for (
                    Integer l = adjustmentTaxes.size() - 1;
                    l >= 0;
                    l--
                ) {
                    adjustmentTaxes.remove(
                        adjustmentTaxes.get(l)
                    );
                }
            }
        }
    }

    /**
     * Removes existing TAX validation outputs.
     */
    public virtual void existingCartValidationMessageCleanUp(
        CartExtension.Cart cart
    ) {
        CartExtension.CartValidationOutputList
            cartValidationOutputCollection =
                cart.getCartValidationOutputs();

        for (
            Integer i = cartValidationOutputCollection.size() - 1;
            i >= 0;
            i--
        ) {
            CartExtension.CartValidationOutput cvo =
                cartValidationOutputCollection.get(i);

            if (
                cvo.getType()
                == CartExtension.CartValidationOutputTypeEnum.TAXES
            ) {
                cartValidationOutputCollection.remove(cvo);
            }
        }
    }

    /**
     * Applies returned tax details to the Commerce cart.
     */
    public virtual void setTaxInCart(
        CartExtension.Cart cart,
        LwrCca_TaxMetaData taxMetaData,
        LwrCca_TaxProviderResponse tpResponse
    ) {
        Map<String, LwrCca_TaxableCartItem> tLineItems;

        if (!Test.isRunningTest()) {
            tLineItems = tpResponse.taxableCartItems;
        } else {
            tLineItems =
                new Map<String, LwrCca_TaxableCartItem>();
        }

        if (tLineItems == null) {
            System.debug(
                LoggingLevel.ERROR,
                '### SET TAX IN CART: provider response contained no taxableCartItems.'
            );
            return;
        }

        System.debug(
            LoggingLevel.ERROR,
            '### SET TAX IN CART: response keys='
            + tLineItems.keySet()
        );

        CartExtension.CartItemList cartItemCollection =
            cart.getCartItems();

        for (
            Integer i = cartItemCollection.size() - 1;
            i >= 0;
            i--
        ) {
            CartExtension.CartItem cartItem =
                cartItemCollection.get(i);

            if (
                !taxMetaData.shippingItemsTaxable
                && cartItem.getType()
                    == CartExtension.SalesItemTypeEnum.CHARGE
            ) {
                continue;
            }

            String lookupKey;

            if (
                cartItem.getType()
                == CartExtension.SalesItemTypeEnum.PRODUCT
            ) {
                lookupKey = cartItem.getId();
            } else {
                lookupKey =
                    cartItem.getCartDeliveryGroup().getId();
            }

            LwrCca_TaxableCartItem tLineItem =
                tLineItems.get(lookupKey);

            System.debug(
                LoggingLevel.ERROR,
                '### SET TAX LOOKUP'
                + ' | cartItemId=' + cartItem.getId()
                + ' | type=' + cartItem.getType()
                + ' | lookupKey=' + lookupKey
                + ' | found=' + (tLineItem != null)
            );

            if (tLineItem == null) {
                continue;
            }

            System.debug(
                LoggingLevel.ERROR,
                '### SET TAX ITEM'
                + ' | id=' + tLineItem.id
                + ' | sku=' + tLineItem.sku
                + ' | amount=' + tLineItem.amount
                + ' | quantity=' + tLineItem.quantity
                + ' | taxDetails=' + tLineItem.lineItemTexas
            );

            if (tLineItem.lineItemTexas == null) {
                continue;
            }

            for (
                LwrCca_LineItemTaxDetails litDetails :
                tLineItem.lineItemTexas
            ) {
                if (litDetails == null) {
                    continue;
                }

                CartExtension.CartTaxList cartTaxCollection =
                    cartItem.getCartTaxes();

                CartExtension.CartTax cartTax =
                    new CartExtension.CartTax(
                        CartExtension.TaxTypeEnum.ESTIMATED,
                        litDetails.tax,
                        'Sales'
                    );

                cartTax.setTaxRate(
                    String.valueOf(litDetails.rate)
                );

                cartTaxCollection.add(cartTax);

                System.debug(
                    LoggingLevel.ERROR,
                    '### CART TAX APPLIED'
                    + ' | cartItemId=' + cartItem.getId()
                    + ' | tax=' + litDetails.tax
                    + ' | rate=' + litDetails.rate
                );
            }
        }
    }

    /**
     * Retrieves tax metadata configuration.
     */
    public virtual LwrCca_TaxMetaData getMetaData(
        String webStoreId,
        String transactionType,
        String docType
    ) {
        return LwrCca_TaxConfiguration.getMetaDataDTO(
            webStoreId,
            transactionType,
            docType
        );
    }

    /**
     * Builds the provider request.
     *
     * Product2 tax fields are deliberately loaded by explicit Product2 Id
     * rather than relying on the CartItem.Product2 relationship for the
     * tax-code assignment.
     */
    public virtual LwrCca_TaxProviderRequest createTaxRequest(
        CartExtension.Cart cart,
        LwrCca_TaxMetaData taxMetaData
    ) {
        Map<String, LwrCca_TaxableCartItem> taxableCartItems =
            new Map<String, LwrCca_TaxableCartItem>();

        LwrCca_TaxProviderRequest request =
            new LwrCca_TaxProviderRequest();

        String cartId = cart.getId();

        request.cartId = cartId;
        request.taxMetaData = taxMetaData;
        request.currencyCode = cart.getCurrencyIsoCode();

        /*
         * -------------------------------------------------------------
         * Delivery group / destination
         * -------------------------------------------------------------
         */
        CartExtension.CartDeliveryGroupList cartDeliveryGroups =
            cart.getCartDeliveryGroups();

        if (cartDeliveryGroups.size() == 1) {
            CartExtension.CartDeliveryGroup cartDeliveryGroup =
                cartDeliveryGroups.get(0);

            request.hasMultipleShipments = false;

            if (cartDeliveryGroup.getDeliverToAddress() != null) {
                request.street =
                    cartDeliveryGroup.getDeliverToAddress().Street;
                request.city =
                    cartDeliveryGroup.getDeliverToAddress().City;
                request.state =
                    cartDeliveryGroup.getDeliverToAddress().State;
                request.postalCode =
                    cartDeliveryGroup.getDeliverToAddress().PostalCode;
                request.country =
                    cartDeliveryGroup.getDeliverToAddress().Country;
            }
        } else {
            request.hasMultipleShipments = true;
        }

        /*
         * -------------------------------------------------------------
         * Build the initial cart-item map from the calculate API.
         * This establishes the authoritative Salesforce CartItem IDs.
         * -------------------------------------------------------------
         */
        CartExtension.CartItemList cartItemCollection =
            cart.getCartItems();

        for (
            Integer i = cartItemCollection.size() - 1;
            i >= 0;
            i--
        ) {
            CartExtension.CartItem cartItem =
                cartItemCollection.get(i);

            System.debug(
                LoggingLevel.ERROR,
                '### CART ITEM ID=' + cartItem.getId()
                + ' | SKU=' + cartItem.getSku()
                + ' | TYPE=' + cartItem.getType()
            );

            if (
                !taxMetaData.shippingItemsTaxable
                && cartItem.getType()
                    == CartExtension.SalesItemTypeEnum.CHARGE
            ) {
                continue;
            }

            LwrCca_TaxableCartItem tcItem =
                new LwrCca_TaxableCartItem();

            tcItem.amount = cartItem.getTotalAmount();
            tcItem.quantity = cartItem.getQuantity();
            tcItem.sku = cartItem.getSku();

            /*
             * Multi-shipment carts require item-level destination data.
             */
            if (request.hasMultipleShipments) {
                CartExtension.CartDeliveryGroup itemDeliveryGroup =
                    cartItem.getCartDeliveryGroup();

                if (
                    itemDeliveryGroup != null
                    && itemDeliveryGroup.getDeliverToAddress() != null
                ) {
                    tcItem.street =
                        itemDeliveryGroup.getDeliverToAddress().Street;
                    tcItem.city =
                        itemDeliveryGroup.getDeliverToAddress().City;
                    tcItem.state =
                        itemDeliveryGroup.getDeliverToAddress().State;
                    tcItem.postalCode =
                        itemDeliveryGroup.getDeliverToAddress().PostalCode;
                    tcItem.country =
                        itemDeliveryGroup.getDeliverToAddress().Country;
                }
            }

            if (
                cartItem.getType()
                == CartExtension.SalesItemTypeEnum.PRODUCT
            ) {
                tcItem.id = cartItem.getId();
                tcItem.lineItemType = 'Product';

                taxableCartItems.put(
                    cartItem.getId(),
                    tcItem
                );

                System.debug(
                    LoggingLevel.ERROR,
                    '### CART PRODUCT MAPPED'
                    + ' | cartItemId=' + cartItem.getId()
                    + ' | sku=' + cartItem.getSku()
                    + ' | amount=' + tcItem.amount
                    + ' | quantity=' + tcItem.quantity
                    + ' | mapKey=' + cartItem.getId()
                );

            } else {
                String deliveryGroupId;

                if (
                    cartItem.getCartDeliveryGroup() != null
                ) {
                    deliveryGroupId =
                        cartItem.getCartDeliveryGroup().getId();
                }

                tcItem.id = deliveryGroupId;
                tcItem.lineItemType = 'Charge';

                tcItem.sku =
                    String.isNotBlank(cartItem.getSku())
                    ? cartItem.getSku()
                    : 'Shipping-Item';

                if (String.isNotBlank(deliveryGroupId)) {
                    taxableCartItems.put(
                        deliveryGroupId,
                        tcItem
                    );
                }

                System.debug(
                    LoggingLevel.ERROR,
                    '### CART CHARGE MAPPED'
                    + ' | cartItemId=' + cartItem.getId()
                    + ' | deliveryGroupId=' + deliveryGroupId
                    + ' | sku=' + tcItem.sku
                    + ' | amount=' + tcItem.amount
                );
            }
        }

        /*
         * -------------------------------------------------------------
         * DB enrichment
         *
         * First load the CartItems for the cart and collect Product2Ids.
         * Then explicitly query Product2 by Id.
         *
         * This avoids depending on CartItem.Product2 relationship
         * materialization when deciding the tax class.
         * -------------------------------------------------------------
         */
        if (
            taxMetaData.useProductTaxCodes
            || taxMetaData.productTaxExemption
        ) {
            System.debug(
                LoggingLevel.ERROR,
                '### TAX REQUEST CONFIG'
                + ' | cartId=' + cartId
                + ' | useProductTaxCodes='
                    + taxMetaData.useProductTaxCodes
                + ' | productTaxExemption='
                    + taxMetaData.productTaxExemption
                + ' | defaultProductTaxCode='
                    + taxMetaData.defaultProductTaxCode
                + ' | defaultShippingTaxCode='
                    + taxMetaData.defaultShippingTaxCode
                + ' | shippingItemsTaxable='
                    + taxMetaData.shippingItemsTaxable
            );

            String cartItemQuery =
                'SELECT '
                + 'Id, '
                + 'Sku, '
                + 'Quantity, '
                + 'TotalLineAmount, '
                + 'Type, '
                + 'Product2Id, '
                + 'CartDeliveryGroup.Id '
                + 'FROM CartItem '
                + 'WHERE CartId = :cartId';

            if (!taxMetaData.shippingItemsTaxable) {
                cartItemQuery +=
                    ' AND Type = \'Product\'';
            }

            System.debug(
                LoggingLevel.ERROR,
                '### TAX CARTITEM QUERY=' + cartItemQuery
            );

            List<CartItem> dbCartItems =
                Database.query(cartItemQuery);

            /*
             * Collect every Product2 Id that actually belongs to the
             * CartItems in this cart.
             */
            Set<Id> productIds =
                new Set<Id>();

            for (CartItem dbCartItem : dbCartItems) {
                if (dbCartItem.Product2Id != null) {
                    productIds.add(
                        dbCartItem.Product2Id
                    );
                }
            }

            /*
             * Explicitly load Product2 records.
             */
            Map<Id, Product2> productsById =
                new Map<Id, Product2>();

            if (!productIds.isEmpty()) {
                String productQuery =
                    'SELECT '
                    + 'Id, '
                    + 'Taxable__c, '
                    + 'Tax_Class_Id__c, '
                    + 'Entity_Use_Code__c, '
                    + 'Exemption_Code__c '
                    + 'FROM Product2 '
                    + 'WHERE Id IN :productIds';

                System.debug(
                    LoggingLevel.ERROR,
                    '### TAX PRODUCT QUERY=' + productQuery
                );

                for (
                    Product2 product :
                    Database.query(productQuery)
                ) {
                    productsById.put(
                        product.Id,
                        product
                    );
                }
            }

            /*
             * Apply Product2 data to the authoritative CartItem map.
             */
            for (CartItem dbCartItem : dbCartItems) {

                Product2 product =
                    productsById.get(
                        dbCartItem.Product2Id
                    );

                System.debug(
                    LoggingLevel.ERROR,
                    '### TAX DB VALUE'
                    + ' | CartItem=' + dbCartItem.Id
                    + ' | Type=' + dbCartItem.Type
                    + ' | SKU=' + dbCartItem.SKU
                    + ' | Product2Id=' + dbCartItem.Product2Id
                    + ' | ProductFound=' + (product != null)
                    + ' | ProductTaxable='
                        + (
                            product == null
                            ? 'NULL_PRODUCT'
                            : String.valueOf(
                                product.Taxable__c
                            )
                        )
                    + ' | ProductTaxClass='
                        + (
                            product == null
                            ? 'NULL_PRODUCT'
                            : product.Tax_Class_Id__c
                        )
                    + ' | useProductTaxCodes='
                        + taxMetaData.useProductTaxCodes
                );

                LwrCca_TaxableCartItem tci;

                /*
                 * Use the same keying strategy as the calculate-API map.
                 */
                if (
                    dbCartItem.Type == 'Product'
                ) {
                    tci =
                        taxableCartItems.get(
                            dbCartItem.Id
                        );
                } else {
                    String deliveryGroupId;

                    if (
                        dbCartItem.CartDeliveryGroup != null
                    ) {
                        deliveryGroupId =
                            dbCartItem.CartDeliveryGroup.Id;
                    }

                    tci =
                        taxableCartItems.get(
                            deliveryGroupId
                        );
                }

                System.debug(
                    LoggingLevel.ERROR,
                    '### TAX TCI LOOKUP'
                    + ' | CartItem=' + dbCartItem.Id
                    + ' | Type=' + dbCartItem.Type
                    + ' | tciFound=' + (tci != null)
                    + ' | tciBefore='
                        + (
                            tci == null
                            ? 'NULL'
                            : String.valueOf(
                                tci.taxClassId
                            )
                        )
                );

                if (tci == null) {
                    System.debug(
                        LoggingLevel.ERROR,
                        '### TAX TCI LOOKUP FAILED'
                        + ' | CartItem=' + dbCartItem.Id
                        + ' | Type=' + dbCartItem.Type
                        + ' | Product2Id=' + dbCartItem.Product2Id
                    );
                    continue;
                }

                /*
                 * -----------------------------------------------------
                 * Product exemption metadata
                 * -----------------------------------------------------
                 */
                if (
                    taxMetaData.productTaxExemption
                    && product != null
                ) {
                    Boolean productIsTaxable =
                        product.Taxable__c;

                    System.debug(
                        LoggingLevel.ERROR,
                        '### TAX EXEMPTION CHECK'
                        + ' | CartItem=' + dbCartItem.Id
                        + ' | ProductTaxable=' + productIsTaxable
                        + ' | ExemptionCode='
                            + product.Exemption_Code__c
                        + ' | EntityUseCode='
                            + product.Entity_Use_Code__c
                    );

                    if (!productIsTaxable) {
                        tci.productExemptionCode =
                            product.Exemption_Code__c;

                        tci.entityUseCode =
                            product.Entity_Use_Code__c;
                    }
                }

                /*
                 * -----------------------------------------------------
                 * Product tax code
                 *
                 * Explicit Product2 lookup:
                 * PF051906 should be used when Product2.Tax_Class_Id__c
                 * contains PF051906.
                 *
                 * P0000000 is only the configured fallback for products
                 * that do not have a Product2 tax class.
                 * -----------------------------------------------------
                 */
                if (taxMetaData.useProductTaxCodes) {

                    if (
                        product != null
                        && String.isNotBlank(
                            product.Tax_Class_Id__c
                        )
                    ) {
                        tci.taxClassId =
                            product.Tax_Class_Id__c;

                        System.debug(
                            LoggingLevel.ERROR,
                            '### TAX CODE MAPPED FROM PRODUCT2'
                            + ' | CartItem=' + dbCartItem.Id
                            + ' | SKU=' + dbCartItem.SKU
                            + ' | Product2Id=' + dbCartItem.Product2Id
                            + ' | ProductTaxClass='
                                + product.Tax_Class_Id__c
                            + ' | tci.taxClassId='
                                + tci.taxClassId
                        );

                    } else if (
                        dbCartItem.Type == 'Product'
                    ) {
                        tci.taxClassId =
                            taxMetaData.defaultProductTaxCode;

                        System.debug(
                            LoggingLevel.ERROR,
                            '### TAX CODE DEFAULTED PRODUCT'
                            + ' | CartItem=' + dbCartItem.Id
                            + ' | SKU=' + dbCartItem.SKU
                            + ' | Product2Id='
                                + dbCartItem.Product2Id
                            + ' | ProductFound='
                                + (product != null)
                            + ' | ProductTaxClass='
                                + (
                                    product == null
                                    ? 'NULL'
                                    : product.Tax_Class_Id__c
                                )
                            + ' | Default='
                                + taxMetaData.defaultProductTaxCode
                            + ' | tci.taxClassId='
                                + tci.taxClassId
                        );

                    } else {
                        tci.taxClassId =
                            taxMetaData.defaultShippingTaxCode;

                        System.debug(
                            LoggingLevel.ERROR,
                            '### TAX CODE DEFAULTED SHIPPING'
                            + ' | CartItem=' + dbCartItem.Id
                            + ' | Default='
                                + taxMetaData.defaultShippingTaxCode
                            + ' | tci.taxClassId='
                                + tci.taxClassId
                        );
                    }

                } else {
                    System.debug(
                        LoggingLevel.ERROR,
                        '### TAX CODE BLOCK SKIPPED'
                        + ' | CartItem=' + dbCartItem.Id
                        + ' | Type=' + dbCartItem.Type
                        + ' | useProductTaxCodes='
                            + taxMetaData.useProductTaxCodes
                    );
                }

                System.debug(
                    LoggingLevel.ERROR,
                    '### TAX TCI FINAL'
                    + ' | CartItem=' + dbCartItem.Id
                    + ' | SKU=' + dbCartItem.SKU
                    + ' | Type=' + dbCartItem.Type
                    + ' | Product2Id=' + dbCartItem.Product2Id
                    + ' | taxClassId=' + tci.taxClassId
                    + ' | exemptionCode='
                        + tci.productExemptionCode
                    + ' | entityUseCode='
                        + tci.entityUseCode
                );
            }
        }

        request.taxTransacionType =
            taxMetaData.documentType != null
            ? taxMetaData.documentType
            : 'SalesOrder';

        request.taxableCartItems =
            taxableCartItems;

        System.debug(
            LoggingLevel.ERROR,
            '### TAX REQUEST FINAL'
            + ' | cartId=' + request.cartId
            + ' | transactionType='
                + request.taxTransacionType
            + ' | hasMultipleShipments='
                + request.hasMultipleShipments
            + ' | taxableCartItems='
                + JSON.serialize(
                    request.taxableCartItems
                )
        );

        return request;
    }

    /**
     * Loads customer exemption details from the current user's Account.
     */
    public virtual void setExemptionDetails(
        LwrCca_TaxProviderRequest taxProviderRequest,
        LwrCca_TaxMetaData taxMetaData
    ) {
        if (!taxMetaData.customerTaxExemption) {
            return;
        }

        User user = [
            SELECT
                Id,
                AccountId,
                Account.Exemption_Code__c,
                Account.Entity_Use_Code__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (user.Account != null) {
            taxProviderRequest.customerExemptionCode =
                user.Account.Exemption_Code__c;

            taxProviderRequest.entityUseCode =
                user.Account.Entity_Use_Code__c;
        }

        System.debug(
            LoggingLevel.ERROR,
            '### CUSTOMER EXEMPTION DETAILS'
            + ' | accountId=' + user.AccountId
            + ' | exemptionCode='
                + taxProviderRequest.customerExemptionCode
            + ' | entityUseCode='
                + taxProviderRequest.entityUseCode
        );
    }
}