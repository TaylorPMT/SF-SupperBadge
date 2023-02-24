public with sharing class MaintenanceRequestHelper {
    public static void updateMaintenceRequest(List<Case> listOfCaseTrigger) {
        List<Id> listOfCaseId = new List<Id>();
        List<String> requestOfType = new List<String>{ 'Repair', 'Routine Maintenance' };
        for (Case iterableOfCase : listOfCaseTrigger) {
            if (requestOfType.contains((String) iterableOfCase.get('type')) && iterableOfCase.IsClosed) {
                listOfCaseId.add((Id) iterableOfCase.get('Id'));
            }
        }

        if (!listOfCaseId.isEmpty()) {
            List<Case> listOfCaseNew = new List<Case>();
            Map<Id, Case> mapOfCaseRequest = new Map<Id, Case>(
                [
                    SELECT
                        Id,
                        Vehicle__c,
                        (
                            SELECT Id, Equipment__c, Equipment__r.Maintenance_Cycle__c
                            FROM Equipment_Maintenance_Items__r
                        )
                    FROM Case
                    WHERE Id IN :listOfCaseId
                ]
            );
            for (Id idCase : mapOfCaseRequest.keySet()) {
                Case cloneCaseWithRel = mapOfCaseRequest.get(idCase).clone(false, true);
                cloneCaseWithRel.Type = requestOfType.get(1);
                cloneCaseWithRel.Subject = requestOfType.get(1);
                cloneCaseWithRel.Date_Reported__c = Date.today();
                List<Decimal> minDueAtDate = new List<Decimal>();
                if (cloneCaseWithRel.Equipment_Maintenance_Items__r.size() > 0) {
                    for (SObject itemEquiqment : cloneCaseWithRel.Equipment_Maintenance_Items__r) {
                        minDueAtDate.add((Decimal) itemEquiqment.getSObject('Equipment__r').get('Maintenance_Cycle__c'));
                    }
                }
                if (minDueAtDate.size() > 0) {
                    minDueAtDate.sort();
                    cloneCaseWithRel.Date_Due__c = Date.today().addDays((Integer) minDueAtDate.get(0));
                }
                listOfCaseNew.add(cloneCaseWithRel);
            }
            Database.insert(listOfCaseNew);
            List<SObject> listOfRelWithCase = new List<SObject>();
            for (Case iterableOfCase : listOfCaseNew) {
                List<SObject> relCase = iterableOfCase.getSObjects('Equipment_Maintenance_Items__r').deepClone(false);
                for (SObject itemRel : relCase) {
                    itemRel.put('Maintenance_Request__c', iterableOfCase.Id);
                    listOfRelWithCase.add(itemRel);
                }
            }
            Database.insert(listOfRelWithCase);
        }
    }
}
