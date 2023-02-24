public with sharing class WarehouseCalloutService implements System.Queueable {
    private static final String URL_CALL_OUT = 'https://th-superbadge-apex.herokuapp.com/equipment';
    @future(callout=true)
    public static void runWarehouseEquipmentSync() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(URL_CALL_OUT);
        request.setMethod('GET');
        HttpResponse res = http.send(request);
        List<Object> listOfJsonDesriable = (List<Object>) JSON.deserializeUntyped(res.getBody());
        upsertInventoryManagement(listOfJsonDesriable);
    }

    private static void upsertInventoryManagement(List<Object> listOfJsonDesriable) {
        List<Product2> listOfProduct = new List<Product2>();
        for (Object iterableOfProduct : listOfJsonDesriable) {
            Map<String, Object> mapOfProductObject = (Map<String, Object>) iterableOfProduct;
            Product2 newOfProduct = new Product2();
            newOfProduct.Name = (String) mapOfProductObject.get('name');
            newOfProduct.Maintenance_Cycle__c = (Integer) mapOfProductObject.get('maintenanceperiod');
            newOfProduct.Cost__c = (Integer) mapOfProductObject.get('cost');
            newOfProduct.Current_Inventory__c = ((Integer) mapOfProductObject.get('qIntegerntity'));
            newOfProduct.Lifespan_Months__c = (Integer) mapOfProductObject.get('lifespan');
            newOfProduct.Replacement_Part__c = true;
            newOfProduct.Warehouse_SKU__c = (String) mapOfProductObject.get('sku');
            newOfProduct.ProductCode = (String) mapOfProductObject.get('_id');
            listOfProduct.add(newOfProduct);
        }

        Database.upsert(listOfProduct);
    }

    public static void execute(QueueableContext context) {
        runWarehouseEquipmentSync();
    }
}
