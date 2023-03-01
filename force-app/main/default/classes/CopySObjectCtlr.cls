public with sharing class CopySObjectCtlr {
    private static final String LABEL_CLONE = System.Label.Clone_Prefix;
    private static final Integer MAX_LENGTH_CLONE = 40;
    private static final String TOAST_ERROR = System.Label.Toast_Error_Clone;
    @AuraEnabled
    public static Id cloneSObject(String recordId) {
        try {
            SobjectCloneUtils cloner = new SobjectCloneUtils(
                (Id) recordId,
                new Map<String, String>{
                    // ermt__incident__c
                    'ERMT__INCIDENTS__R' => 'INTEGRATEDRECORD__R',
                    //ermt__risk__c
                    'ERMT__RISKORGANIZATION__R' => 'ERMT__RISKPROFILE__R',
                    // ermt_Control__c
                    'ERMT__TREATMENTASSIGNEDORG__R' => ''
                }
            );
            cloner.addlookupFieldsMap('INTEGRATEDRECORD__R', 'INTEGRATEDRECORD__C');
            cloner.addlookupFieldsMap('ERMT__RISKPROFILE__R', 'ERMT__RISKPROFILE__C');

            SObject beforeSObjectClone = (SObject) cloner.clone;
            String namePrefix = String.join(new List<String>{ (String) beforeSObjectClone.get('Name'), LABEL_CLONE }, '');
            if (namePrefix.length() > MAX_LENGTH_CLONE) {
                namePrefix = namePrefix.substring(0, MAX_LENGTH_CLONE);
            }
            beforeSObjectClone.put('Name', namePrefix);
            Id IdRecord = cloner.save();
            return IdRecord;
        } catch (Exception e) {
            String messageError = String.format(TOAST_ERROR, new List<String>{ e.getMessage(), '</br>' });
            throw new AuraHandledException(messageError);
        }
    }
}
