public with sharing class CopySObjectCtlr {
    private static final String LABEL_COPY_ACCOUNT = System.Label.Label_CopyAccount;
    public static final Integer MAX_LENGTH_ACCOUNT_NAME = 40;

    @AuraEnabled
    public static Id copyAccount(String recordId) {
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

            Account beforeCloneAccount = (Account) cloner.clone;
            String nameClone = String.join(new List<String>{ beforeCloneAccount.Name, LABEL_COPY_ACCOUNT }, '');
            if (nameClone.length() > MAX_LENGTH_ACCOUNT_NAME) {
                nameClone = nameClone.substring(0, MAX_LENGTH_ACCOUNT_NAME);
            }
            beforeCloneAccount.Name = nameClone;
            Id accountId = cloner.save();
            return accountId;
        } catch (Exception e) {
            String text = 'エラー 部署コピー: {0} {1} システム管理者までご連絡ください';
            String messageError = String.format(text, new List<String>{ e.getMessage(), '</br>' });
            throw new AuraHandledException(messageError);
        }
    }
}
