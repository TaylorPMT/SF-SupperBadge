@isTest
private class MaintenanceRequestHelperTest {
    @testSetup
    static void testSetup() {
        Account acc = new Account();
        acc.Name = 'test';
        insert acc;

        Contact contact = new Contact();
        contact.FirstName = 'test';
        contact.LastName = 'last';
        contact.Email = 'test@test.com';
        contact.AccountId = acc.Id;
        insert contact;

        Vehicle__c vehicle = new Vehicle__c();
        vehicle.Name = 'car';
        insert vehicle;

        Product2 product = new Product2();
        product.Name = 'test';
        product.isActive = true;
        product.Maintenance_Cycle__c = 2;
        product.Replacement_Part__c = true;
        insert product;
    }

    @isTest
    static void testTriggerMaintenanceRequestHelper() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        User newOfUser = new User(
            Alias = 'stdtest',
            Email = 'stdtest@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'stdtest@testorg.com'
        );

        System.runAs(newOfUser) {
            List<Case> listOfCase = new List<Case>();
            List<Case> listNewOfCase = new List<Case>();

            //grab the data that was created in the testSetup method
            Account acc = [SELECT Id, Name FROM Account WHERE Name = 'test' LIMIT 1];
            Contact contact = [SELECT Id, FirstName, LastName, Email, AccountId FROM Contact WHERE Email = 'test@test.com' LIMIT 1];
            Vehicle__c vehicle = [SELECT Id, Name FROM Vehicle__c WHERE Name = 'car' LIMIT 1];
            Product2 product = [SELECT Id, Name, isActive, Maintenance_Cycle__c, Replacement_Part__c FROM Product2 WHERE Name = 'test' LIMIT 1];

            Test.startTest();

            for (Integer i = 1; i <= 300; i++) {
                Case maintenanceNew = new Case();
                maintenanceNew.Subject = 'Other';
                maintenanceNew.Vehicle__c = vehicle.Id;
                maintenanceNew.Product__c = product.Id;
                maintenanceNew.ContactId = contact.Id;
                maintenanceNew.AccountId = acc.Id;
                maintenanceNew.Type = 'Other';
                maintenanceNew.Status = 'New';
                maintenanceNew.Date_Reported__c = Date.today();
                maintenanceNew.Date_Due__c = Date.today();

                listOfCase.add(maintenanceNew);
            }

            insert listOfCase;
            List<Equipment_Maintenance_Item__c> listOfEnquiMaintenance = new List<Equipment_Maintenance_Item__c>();
            System.assertEquals(300, listOfCase.size());

            for (Case interableCase : listOfCase) {
                //update information
                interableCase.Type = 'Repair';
                interableCase.Status = 'Closed';
                listNewOfCase.add(interableCase);
                listOfEnquiMaintenance.add(new Equipment_Maintenance_Item__c(
                    Equipment__c = product.Id,
                    Maintenance_Request__c = interableCase.Id
                ));
            }
            insert listOfEnquiMaintenance;
            update listNewOfCase;
            List<Case> createdCases = [SELECT Id FROM Case WHERE Type = 'Routine Maintenance'];
            System.assertEquals(300, createdCases.size());

            Test.stopTest();
        }

    }
}
