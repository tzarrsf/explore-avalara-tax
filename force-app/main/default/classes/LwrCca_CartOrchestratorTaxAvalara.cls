/**
 * @description       : Minimal Cart Calculate orchestrator used to isolate and validate
 *                      the Avalara tax integration in B2B Store.
 *
 *                      Runs native pricing, minimal post-shipping processing,
 *                      and tax calculation. Pricing/promotions/inventory/shipping
 *                      calculators are otherwise left out of the test path.
 *
 * @author            : Tom Zarr
 * @group             : Salesforce Commerce Partner Enablement Success
 * @last modified on  : 08-18-2026
 * @last modified by  : Tom Zarr
**/
global class LwrCca_CartOrchestratorTaxAvalara extends CartExtension.CartCalculate
{
    global LwrCca_CartOrchestratorTaxAvalara() { }

    global LwrCca_CartOrchestratorTaxAvalara(
        final CartExtension.CartCalculateExecutorMock apexExecutor
    )
    {
        super(apexExecutor);
    }

	/**
	 * This code is a crude example meant for isolation testing with Avalara. It's moste definitely not following best practices.
	 */
    global virtual override void calculate(CartExtension.CartCalculateOrchestratorRequest request)
    {
        System.debug(
            LoggingLevel.INFO,
            '### LwrCca_CartOrchestratorTaxAvalara.calculate()'
        );

        CartExtension.Cart cart = request.getCart();

        CartExtension.CartCalculateCalculatorRequest calculatorRequest =
            new CartExtension.CartCalculateCalculatorRequest(
                cart,
                request.getOptionalBuyerActionDetails()
            );

        CartExtension.BuyerActions buyerActions = request.getBuyerActions();

        /*
         * Native pricing.
         */
        System.debug(
            LoggingLevel.INFO,
            '### Calling prices()...'
        );

        prices(calculatorRequest);

        if (hasErrorLevelCartValidationOutput(
                cart.getCartValidationOutputs(),
                CartExtension.CartValidationOutputTypeEnum.PRICING
            )) {
            System.debug(
                LoggingLevel.ERROR,
                '### Pricing produced an ERROR CVO. Stopping.'
            );
            return;
        }

        /*
         * Minimal post-shipping support for checkout.
         */
        Boolean runPostShipping =
            buyerActions.isCheckoutStarted() ||
            buyerActions.isDeliveryGroupChanged() ||
            buyerActions.isDeliveryMethodSelected();

        if (runPostShipping) {
            System.debug(
                LoggingLevel.INFO,
                '### Calling postShipping()...'
            );

            postShipping(calculatorRequest);

            if (hasErrorLevelCartValidationOutput(
                    cart.getCartValidationOutputs(),
                    CartExtension.CartValidationOutputTypeEnum.SYSTEM_ERROR
                )) {
                System.debug(
                    LoggingLevel.ERROR,
                    '### postShipping produced a SYSTEM_ERROR CVO. Stopping.'
                );
                return;
            }
        }

        /*
         * Avalara isolation mode.
         */
        System.debug(
            LoggingLevel.INFO,
            '### Calling taxes()...'
        );

        taxes(calculatorRequest);

        /*
         * Dump any tax-related validation outputs created by the tax
         * calculator. This is diagnostic; the helper does not catch
         * exceptions thrown inside the tax extension itself.
         */
        Boolean taxError = hasErrorLevelCartValidationOutput(
            cart.getCartValidationOutputs(),
            CartExtension.CartValidationOutputTypeEnum.TAXES
        );

        System.debug(
            taxError
                ? LoggingLevel.ERROR
                : LoggingLevel.INFO,
            '### Tax CVO error=' + taxError
        );
    }

    private Boolean hasErrorLevelCartValidationOutput(
        CartExtension.CartValidationOutputList cartValidationOutputs,
        CartExtension.CartValidationOutputTypeEnum cartValidationOutputType
    ) {
        Iterator<CartExtension.CartValidationOutput> iterator =
            cartValidationOutputs.iterator();

        while (iterator.hasNext()) {
            CartExtension.CartValidationOutput cvo = iterator.next();

            System.debug(
                LoggingLevel.ERROR,
                'CVO => type=' + cvo.getType() +
                ', level=' + cvo.getLevel() +
                ', message=' + cvo.getMessage()
            );

            Boolean cvoContainsCalculatorError =
                cvo.getType() == cartValidationOutputType &&
                cvo.getLevel() ==
                    CartExtension.CartValidationOutputLevelEnum.ERROR;

            if (cvoContainsCalculatorError) {
                return true;
            }
        }

        return false;
    }
}