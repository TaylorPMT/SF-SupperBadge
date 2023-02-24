@isTest
private class WarehouseCalloutServiceTest {
    @isTest
    static void warehouseEquipmentSync() {
        Test.setMock(HttpCalloutMock.class, new WarehouseCalloutServiceMock());
        Test.startTest();
        WarehouseCalloutService.runWarehouseEquipmentSync();
        System.enqueueJob(new WarehouseCalloutService());
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Product2]);
    }
}
