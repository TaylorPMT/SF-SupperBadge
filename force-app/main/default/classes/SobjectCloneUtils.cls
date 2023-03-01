public with sharing class SobjectCloneUtils {
    public SObject clone;
    public Map<String, String> explodeFieldsByRelNameMap;
    public Map<String, List<SObject>> recordInsertMap;
    public Map<String, List<SObject>> allRecordInsertMap;
    public Map<String, List<SObject>> childLookupRecordInsertMap;
    public List<SObject> listRecordSObjectJunc;
    public Map<Id, SObject> cloneJuncRecordMap;
    public Map<String, Map<Id, Id>> relatedNameListIdMap;
    public Map<String, List<String>> filterClonableFieldsMap;
    public static final List<CopyAccountConfiguration__mdt> COPY_ACCOUNT_CONFIG = getConfigCopyAccount();
    /**
     * @description Constructor without object query.  Allows more control of cloning
     * @param recordId: SObject to clone.  Must include all relevant information
     * @param relationshipCloneMap: Child Relationship names
     */
    public SobjectCloneUtils(Id recordId, Map<String, String> relationshipCloneMap) {
        this.listRecordSObjectJunc = new List<SObject>();
        this.explodeFieldsByRelNameMap = new Map<String, String>();
        this.recordInsertMap = new Map<String, List<SObject>>();
        this.allRecordInsertMap = new Map<String, List<SObject>>();
        this.childLookupRecordInsertMap = new Map<String, List<SObject>>();
        this.relatedNameListIdMap = new Map<String, Map<Id, Id>>();
        this.filterClonableFieldsMap = getFilterClonableFields();
        this.sobjectTypeClone = getSObjectTypeCloneByID(recordId);
        this.relationshipMap = getRelationshipDetails(relationshipCloneMap);
        this.listFieldLookupCloneMap = relationshipCloneMap;
        this.clone = getByRecordId(recordId);
    }

    public void addlookupFieldsMap(String relation, String customField) {
        this.explodeFieldsByRelNameMap.put(relation, customField);
    }

    public Id save() {
        // setup the save point for rollback
        Savepoint sp = Database.setSavepoint();

        try {
            if (this.clone != null) {
                Boolean checkCloneParentLookup = false;
                List<SObject> cloneRecordList = new List<SObject>();
                List<SObject> cloneRecordParent = new List<SObject>();
                List<String> listLookupFields = new List<String>();
                List<String> listChilRelName = new List<String>();
                Map<String, String> fieldsLookupRelNameMap = this.listFieldLookupCloneMap;
                //DML insert clone insert clone Account
                insert this.clone;
                // relationshipMap :childRelName relationship map , use for loop
                for (String childRelName : this.relationshipMap.keySet()) {
                    Map<String, SObject> clonedLookup = new Map<String, SObject>();
                    List<SObject> clonedChildrenList = new List<SObject>();
                    ChildRelationshipProps rel = this.relationshipMap.get(childRelName);
                    // get lookup relationship result by childRelName

                    String lookupFieldRelName = fieldsLookupRelNameMap.get(childRelName);
                    // Get lookup parent relation result
                    for (SObject child : clone.getSObjects(childRelName)) {
                        SObjectField dFieldNameRelResult = rel.field;
                        if (String.isNotBlank(lookupFieldRelName) && child.getSObject(lookupFieldRelName) != null) {
                            SObject getLookupFields = child.getSObject(lookupFieldRelName);
                            // add clone lookup result equals child relationship
                            // ex : rel.field = ermt__Organization__c
                            // check parent lookup fields ermt__Organization__c  = child relationship
                            if (getLookupFields.get(dFieldNameRelResult) == child.get(dFieldNameRelResult)) {
                                SObject parentLookup = getLookupFields.clone(false);
                                // set ermt__Organization__c = Lookup Account
                                parentLookup.put(dFieldNameRelResult, clone.Id);
                                // put clone lookup result map Id , SObject lookupClone
                                clonedLookup.put(parentLookup.getCloneSourceId(), parentLookup);
                                checkCloneParentLookup = true;
                            }
                        }
                    }

                    // get child or not lookup record clone
                    for (SObject child : clone.getSObjects(childRelName)) {
                        SObjectField dFieldNameRelResult = rel.field;
                        // check record clone lookup parent relationship
                        if (clonedLookup.containsKey((String) child.Id)) {
                            continue;
                        }
                        SObject childClone = child.clone(false);
                        childClone.put(dFieldNameRelResult, clone.Id);
                        clonedChildrenList.add(childClone);
                    }

                    // check lookup parent fields exists
                    if (String.isNotBlank(lookupFieldRelName)) {
                        //set childrent lookup fields
                        buildCloneParentRelName(clonedChildrenList, clonedLookup, lookupFieldRelName, childRelName);
                        listLookupFields.add(lookupFieldRelName);
                        listChilRelName.add(childRelName);
                    }
                    // check lookup parent fields exists
                    if (this.recordInsertMap.get(childRelName) != null) {
                        cloneRecordParent.addAll(getRecordListInsertByName(childRelName));
                    }
                    cloneRecordList.addAll(clonedChildrenList);
                    buildAllRecordInsertRelName(childRelName, cloneRecordParent, clonedChildrenList);
                }

                // Use Sort method in list before performing DML operation
                cloneRecordParent.sort();
                // DML insert record parent lookup object with rel name
                insert cloneRecordParent;
                if (checkCloneParentLookup) {
                    upsertCloneParentRelName(listChilRelName);
                }
                // Use Sort method in list before performing DML operation
                cloneRecordList.sort();
                // DML insert record  and lookup with rel name
                insert cloneRecordList;

                // createJunction record
                createRecordJuncByRel();
                insert this.listRecordSObjectJunc;
            }
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }

        return clone.Id;
    }
    /* createRecordJuncByRel
     * Clone juntion relationship with name
     * Push Object insert juction listRecordSObjectJunc
     * List<SObject> Name : ermt__Incident_Risk_Junc__c,ermt__Risk_Control_Junc__c,ermt__Risk_Classification_Junc__c
     */
    private void createRecordJuncByRel() {
        // Build a map Relationship Name , of clone source id and IDs
        getMapCloneSourceId();
        // Dml get childRelName by list clone source id
        getRiskJuncWithRel();
        Map<Id, Id> newRecordRiskIdMap = this.relatedNameListIdMap.get('ERMT__RISKORGANIZATION__R') != null
            ? this.relatedNameListIdMap.get('ERMT__RISKORGANIZATION__R')
            : new Map<Id, Id>();
        Map<Id, Id> newRecordIncidentIdMap = this.relatedNameListIdMap.get('ERMT__INCIDENTS__R') != null
            ? this.relatedNameListIdMap.get('ERMT__INCIDENTS__R')
            : new Map<Id, Id>();
        Map<Id, Id> mapIdOldNewControl = this.relatedNameListIdMap.get('ERMT__TREATMENTASSIGNEDORG__R') != null
            ? this.relatedNameListIdMap.get('ERMT__TREATMENTASSIGNEDORG__R')
            : new Map<Id, Id>();

        for (Id sourceIdClone : newRecordRiskIdMap.keySet()) {
            SObject junctionObject = this.cloneJuncRecordMap.get(sourceIdClone);
            // Build record risk control junc
            // The value of ermt__Risk__c is「New risk Object」、
            // The value entered in ermt__control__c is the record created(「New Control Object」)
            createRiskControlJunc(junctionObject, sourceIdClone, newRecordRiskIdMap, mapIdOldNewControl);
            // Build record risk classification junc
            createRiskClassificationJunc(junctionObject, sourceIdClone, newRecordRiskIdMap);
            // End build record risk classification junc

            // Value of ermt__Risk__c is「New risk Object」、
            // value of ermt__M_Classification__c will create same as「ermt__Risk_Classification_Junc__c Object」
            // - ermt__M_Classification__c
            // Build record incident risk junc
            createIncidentRiskJunc(junctionObject, sourceIdClone, newRecordRiskIdMap, newRecordIncidentIdMap);
        }

        // Build record risk control juncs not with rel
        createRiskControlJuncNotWithRel(newRecordRiskIdMap, mapIdOldNewControl);
        //end Build record risk control juncs not with rel

        //Build record incident risk junc
        //In case there is ermt__incident__c -「New incident object」, but no ermt__risk__c -「New risk object」then、
        //will create ermt__risk__c as「risk object」
        createIncidentRiskJuncNotWithRel(newRecordIncidentIdMap, newRecordRiskIdMap);
        // Use Sort method in list before performing DML operation

        if (this.listRecordSObjectJunc.size() > 0) {
            this.listRecordSObjectJunc.sort();
        }
    }

    /**
     * @method : createIncidentRiskJuncNotWithRel
     * create record juncs relationship when in case
     * -----------------------------------------------
     * //Build record incident risk junc
     * //In case there is ermt__incident__c -「New incident object」, but no ermt__risk__c -「New risk object」then、
     * //will create ermt__risk__c as「risk object」
     * ------------------------------------------------
     * @param newRecordIncidentIdMap : Map<Id, Id>  (new record incident clone)
     * @ex newRecordIncidentIdMap key map:  id record incident getCloneSourceId , values : id new after clone
     * @param newRecordRiskIdMap : Map<Id, Id>
     * @ex newRecordRiskIdMap key map : id record risk getCloneSourceId , values : id new after clone
     * @return : void method
     **/
    private void createIncidentRiskJuncNotWithRel(Map<Id, Id> newRecordIncidentIdMap, Map<Id, Id> newRecordRiskIdMap) {
        if (newRecordIncidentIdMap.size() > 0) {
            List<Id> listIdIncidentClone = new List<Id>();
            listIdIncidentClone.addAll(newRecordIncidentIdMap.keySet());

            List<SObject> listIncidentRiskJunc = getIncidentRiskJuncByIdIncident(listIdIncidentClone);
            Map<Id, List<Id>> mapIncidentRiskJunc = new Map<Id, List<Id>>();

            if (listIncidentRiskJunc.size() > 0) {
                mapIncidentRiskJunc = getObjectCustomFieldMap(listIncidentRiskJunc, 'ermt__Incident__c', 'ermt__Risk__c');
            }

            List<Id> oldRiskJunc = newRecordRiskIdMap.values();

            for (Id incidentCloneId : newRecordIncidentIdMap.keySet()) {
                List<Id> listRiskIdClone = mapIncidentRiskJunc.get(incidentCloneId) == null
                    ? new List<Id>()
                    : mapIncidentRiskJunc.get(incidentCloneId);

                for (Id idRisk : listRiskIdClone) {
                    if (listRiskIdClone.contains(idRisk) && newRecordRiskIdMap.get(idRisk) == null) {
                        this.listRecordSObjectJunc.add(
                            new ermt__Incident_Risk_Junc__c(
                                ermt__Risk__c = (Id) idRisk,
                                ermt__Incident__c = (Id) newRecordIncidentIdMap.get(incidentCloneId)
                            )
                        );
                    }
                }
            }
        }
    }

    /**
     * @method : createRiskControlJuncNotWithRel
     * -----------------------------------------------
     * //Build record control risk junc
     * //In case there is ermt__control__c -「New control object」, but no ermt__risk__c -「New risk object」then、
     * //will create ermt__risk__c as「risk object」
     * ------------------------------------------------
     * @param newRecordRiskIdMap: Map<Id,Id>
     * @ex newRecordRiskIdMap key map : id record risk getCloneSourceId , values : id new after clone
     * @param mapIdOldNewControl : Map<Id, Id>
     * @ex mapIdOldNewControl key map : id record control getCloneSourceId , values : id new after clone
     * create record juncs relationship when in case
     */
    private void createRiskControlJuncNotWithRel(Map<Id, Id> newRecordRiskIdMap, Map<Id, Id> mapIdOldNewControl) {
        List<Id> listIdControlClone = new List<Id>();
        List<Id> listRiskIdNewRecord = new List<Id>();
        listRiskIdNewRecord.addAll(newRecordRiskIdMap.keySet());
        listIdControlClone.addAll(mapIdOldNewControl.keySet());
        List<SObject> listJuncsControl = getControlJuncsByIdControl(listIdControlClone, listRiskIdNewRecord);
        Map<Id, List<Id>> mapRiskControlJunc = getObjectCustomFieldMap(listJuncsControl, 'ermt__Control__c', 'ermt__Risk__c');

        for (Id controlId : mapRiskControlJunc.keySet()) {
            List<Id> listRiskRel = mapRiskControlJunc.get(controlId);
            Id newIdControlClone = (Id) mapIdOldNewControl.get(controlId);

            for (Id riskRelId : listRiskRel) {
                this.listRecordSObjectJunc.add(new ermt__Risk_Control_Junc__c(ermt__Risk__c = riskRelId, ermt__Control__c = newIdControlClone));
            }
        }
    }

    private void createRiskControlJunc(SObject junctionObject, Id sourceIdClone, Map<Id, Id> newRecordRiskIdMap, Map<Id, Id> mapIdOldNewControl) {
        String childRelationshipName = 'ermt__Risk_Control__r';

        if (junctionObject != null && junctionObject.getSObjects(childRelationshipName) != null) {
            Map<Id, List<Id>> mapRiskControlJunc = getObjectCustomFieldMap(
                junctionObject.getSObjects(childRelationshipName),
                'ermt__Risk__c',
                'ermt__Control__c'
            );

            if (mapRiskControlJunc.get(sourceIdClone) != null) {
                List<Id> listOldIdControl = mapRiskControlJunc.get(sourceIdClone);

                for (Id oldIdNewControl : mapIdOldNewControl.keySet()) {
                    if (listOldIdControl.contains(oldIdNewControl)) {
                        this.listRecordSObjectJunc.add(
                            new ermt__Risk_Control_Junc__c(
                                ermt__Risk__c = (Id) newRecordRiskIdMap.get(sourceIdClone),
                                ermt__Control__c = (Id) mapIdOldNewControl.get(oldIdNewControl)
                            )
                        );
                    }
                }
            }
        }
    }

    private void createRiskClassificationJunc(SObject junctionObject, Id sourceIdClone, Map<Id, Id> newRecordRiskIdMap) {
        String childRelationshipName = 'ermt__Risk_Classification_Junc__r';

        // get record recordInsertMap
        if (junctionObject != null && junctionObject.getSObjects(childRelationshipName) != null) {
            Map<Id, List<Id>> mapRiskClassificationJunc = getObjectCustomFieldMap(
                junctionObject.getSObjects(childRelationshipName),
                'ermt__Risk__c',
                'ermt__M_Classification__c'
            );

            if (mapRiskClassificationJunc.get(sourceIdClone) != null) {
                List<Id> listIdMClassification = mapRiskClassificationJunc.get(sourceIdClone);

                for (Id idMClassification : listIdMClassification) {
                    this.listRecordSObjectJunc.add(
                        new ermt__Risk_Classification_Junc__c(
                            ermt__Risk__c = (Id) newRecordRiskIdMap.get(sourceIdClone),
                            ermt__M_Classification__c = idMClassification
                        )
                    );
                }
            }
        }
    }

    private void pushRecordIncidentRiskJunc(
        Map<Id, Id> newRecordIncidentIdMap,
        List<Id> listIdIncidentClone,
        Map<Id, Id> newRecordRiskIdMap,
        Id sourceIdClone
    ) {
        for (Id oldIncident : newRecordIncidentIdMap.keySet()) {
            if (listIdIncidentClone.contains(oldIncident)) {
                this.listRecordSObjectJunc.add(
                    new ermt__Incident_Risk_Junc__c(
                        ermt__Risk__c = (Id) newRecordRiskIdMap.get(sourceIdClone),
                        ermt__Incident__c = (Id) newRecordIncidentIdMap.get(oldIncident)
                    )
                );
            }
        }
    }

    private void createIncidentRiskJunc(
        SObject junctionObject,
        Id sourceIdClone,
        Map<Id, Id> newRecordRiskIdMap,
        Map<Id, Id> newRecordIncidentIdMap
    ) {
        String childRelationshipName = 'ermt__Incident_Risk_Juncs__r';

        if (junctionObject != null && junctionObject.getSObjects(childRelationshipName) != null) {
            Map<Id, List<Id>> mapIncidentRiskJunc = getObjectCustomFieldMap(
                junctionObject.getSObjects(childRelationshipName),
                'ermt__Risk__c',
                'ermt__Incident__c'
            );
            List<Id> listIdIncidentClone = mapIncidentRiskJunc.get(sourceIdClone);

            //In case both ermt__risk__c and both ermt__incident__c have「New risk object」and「New insident object」then
            //will Create with ermt__risk__c being「New risk object」、ermt__incident__c being「New insident object」
            if (newRecordIncidentIdMap.size() > 0) {
                pushRecordIncidentRiskJunc(newRecordIncidentIdMap, listIdIncidentClone, newRecordRiskIdMap, sourceIdClone);
            }
            //In case there is ermt__Risk__c
            // -「New risk object」, but no ermt__incident__c
            // -「New incident object」then、will Create with ermt__incident__c as「incident object」
            for (Id idIncidentJunc : listIdIncidentClone) {
                if (newRecordIncidentIdMap.containsKey(((Id) idIncidentJunc)) == false) {
                    this.listRecordSObjectJunc.add(
                        new ermt__Incident_Risk_Junc__c(
                            ermt__Risk__c = (Id) newRecordRiskIdMap.get(sourceIdClone),
                            ermt__Incident__c = (Id) idIncidentJunc
                        )
                    );
                }
            }
        }
    }

    /**
     * @methods : getObjectCustomFieldMap
     * @param data : SObject data relationship
     * @param t1: Field Name of SObject ex : ermt__Risk__c
     * @param t2: Field Name of SObject ex : ermt__Incident__c
     * @return A Map of fields id record risk and list id Incident in SObject
     **/
    private Map<Id, List<Id>> getObjectCustomFieldMap(List<SObject> data, String t1, String t2) {
        Map<Id, List<Id>> mapListId = new Map<Id, List<Id>>();
        for (SObject record : data) {
            if (record.get(t1) != null && record.get(t2) != null) {
                Id idt1 = (Id) record.get(t1);
                Id idt2 = (Id) record.get(t2);
                if (mapListId.get(idt1) == null) {
                    mapListId.put(idt1, new List<Id>());
                }
                mapListId.get(idt1).add(idt2);
            }
        }
        return mapListId;
    }

    /**
     * @method : buildAllRecordInsertRelName
     * @param ChildRelationName  : String
     * @param recordParentInsert : List<SObject> record Parent insert,
     * @param recordChildInsert  : List<SObject> record child insert
     * @ex : setup record insert with relation object clone ,
     *       add list<SObject> from record lookup relation and childrent record lookup object rel
     * @return : void method
     **/
    private void buildAllRecordInsertRelName(String childRelName, List<SObject> recordParentInsert, List<SObject> recordChildInsert) {
        if (this.allRecordInsertMap.get(childRelName) == null) {
            this.allRecordInsertMap.put(childRelName, new List<SObject>());
        }
        this.allRecordInsertMap.get(childRelName).addAll(recordParentInsert);
        this.allRecordInsertMap.get(childRelName).addAll(recordChildInsert);
    }

    /**
     *  @method : getMapCloneSourceId
     *  @ex : get list record insert with rel name object by rel clone
     *  @return : void method
     */
    private void getMapCloneSourceId() {
        List<String> listRelationshipName = new List<String>{ 'ERMT__INCIDENTS__R', 'ERMT__RISKORGANIZATION__R', 'ERMT__TREATMENTASSIGNEDORG__R' };
        for (String nameRelation : listRelationshipName) {
            getMapCloneSourceByRelName(nameRelation);
        }
    }

    private void getMapCloneSourceByRelName(String childRelName) {
        List<SObject> resultsRelationship = this.allRecordInsertMap.get(childRelName);

        if (resultsRelationship.size() > 0) {
            this.relatedNameListIdMap.put(childRelName, new Map<Id, Id>());

            for (SObject record : resultsRelationship) {
                this.relatedNameListIdMap.get(childRelName).put(record.getCloneSourceId(), (Id) record.get('Id'));
            }
        }
    }

    /**
     * @method : getRecordListInsertByName
     * @param  childRelName : String(child relationship object clone)
     * @EX     : Account clone record with one to many get record insert <Map, List<SObject>>
     * @return : List<SObject>
     *
     */
    private List<SObject> getRecordListInsertByName(String childRelName) {
        return this.recordInsertMap.get(childRelName);
    }

    private List<SObject> getIncidentRiskJuncByIdIncident(List<Id> listIdIncidentClone) {
        List<SObject> queryJunc = [
            SELECT Id, ermt__Risk__c, ermt__Incident__c
            FROM ermt__Incident_Risk_Junc__c
            WHERE ermt__Incident__c IN :listIdIncidentClone
        ];
        return queryJunc;
    }

    private List<SObject> getControlJuncsByIdControl(List<Id> listIdControlClone, List<Id> listRiskIdNewRecord) {
        List<SObject> queryJunc = [
            SELECT ermt__Control__c, ermt__Risk__c
            FROM ermt__Risk_Control_Junc__c
            WHERE ermt__Control__c IN :listIdControlClone AND ermt__Risk__c NOT IN :listRiskIdNewRecord
        ];
        return queryJunc;
    }

    private Map<string, ChildRelationshipProps> getRelationshipDetails(Map<String, String> relationshipMapClone) {
        Map<String, ChildRelationship> childRelationMap = getChildRel();
        Map<string, ChildRelationshipProps> relationMapDetail = getChildRelName(childRelationMap, relationshipMapClone.keySet());

        return relationMapDetail;
    }

    /**
     * @method getByRecordId
     * DML SOQL get record clone object by id
     * @return SObject
     */
    private SObject getByRecordId(Id toCloneId) {
        // Get a map of field name and field token
        List<String> selectFields = getAllFieldsAPIName(this.sobjectTypeClone);
        // Get relation loookup
        Map<String, String> fieldsLookupRelNameMap = this.listFieldLookupCloneMap;

        //loop relationship build subqueries string
        for (String relationName : this.relationshipMap.keySet()) {
            ChildRelationshipProps rel = this.relationshipMap.get(relationName);
            List<String> relationFields = getAllFieldsAPIName(rel.sObjectType);
            if (relationFields.size() > 0) {
                if (fieldsLookupRelNameMap.get(relationName) != null && String.isNotBlank(fieldsLookupRelNameMap.get(relationName))) {
                    List<String> lookupFieldRelName = buildParentSelectQuery(relationFields, fieldsLookupRelNameMap.get(relationName));
                    if (lookupFieldRelName.size() > 0) {
                        relationFields.addAll(lookupFieldRelName);
                    }
                }

                selectFields.add('(' + buildSelectQuery(relationFields, relationName, null) + ')');
            }
        }
        // Build query string
        String sQuery = buildSelectQuery(selectFields, this.sobjectTypeClone.getDescribe().getName(), 'ID = :toCloneId');
        SObject resultQueryClone = null;
        try {
            List<SObject> resultQuery = Database.query(sQuery);
            resultQueryClone = resultQuery.size() > 0 ? ((SObject) resultQuery[0].clone(false)) : null;
        } catch (System.QueryException e) {
            resultQueryClone = null;
        }

        return resultQueryClone;
    }

    private void getRiskJuncWithRel() {
        Set<Id> listIdRisk = new Set<Id>();

        if (this.relatedNameListIdMap.get('ERMT__RISKORGANIZATION__R') != null) {
            listIdRisk = this.relatedNameListIdMap.get('ERMT__RISKORGANIZATION__R').keySet();
        }

        if (listIdRisk.size() > 0) {
            Map<Id, SObject> mapFromList = new Map<Id, SObject>(
                [
                    SELECT
                        Id,
                        (SELECT Id, ermt__Risk__c, ermt__Control__c FROM ermt__Risk_Control__r),
                        (SELECT Id, ermt__Risk__c, ermt__Incident__c FROM ermt__Incident_Risk_Juncs__r),
                        (SELECT Id, ermt__Risk__c, ermt__M_Classification__c FROM ermt__Risk_Classification_Junc__r)
                    FROM ermt__Risk__c
                    WHERE Id IN :listIdRisk
                ]
            );
            this.cloneJuncRecordMap = mapFromList;
        }
    }

    private Map<String, ChildRelationshipProps> getChildRelName(Map<String, ChildRelationship> childRelation, Set<String> listRelStr) {
        Map<String, ChildRelationshipProps> childRelName = new Map<String, ChildRelationshipProps>();
        for (String relStr : listRelStr) {
            relStr = relStr.toUpperCase();
            if (childRelation.containsKey(relStr)) {
                ChildRelationship rel = childRelation.get(relStr);
                childRelName.put(rel.getRelationshipName().toUpperCase(), new ChildRelationshipProps(rel));
            } else {
                throw new DeepCloneException('Child Relationship \'' + relStr + '\' does not exsist on ' + sobjectTypeClone.getDescribe().getName());
            }
        }
        return childRelName;
    }

    private void upsertCloneParentRelName(List<String> listLookupRelName) {
        for (String lookupRelation : listLookupRelName) {
            String parentNameLookupStr = this.listFieldLookupCloneMap.get(lookupRelation);
            String lookupFieldName = (String) this.explodeFieldsByRelNameMap.get(parentNameLookupStr);

            List<SObject> listRecordParentClone = this.recordInsertMap.get(lookupRelation);
            List<SObject> listRecordChildLookup = this.childLookupRecordInsertMap.get(lookupRelation);
            for (SObject recordParent : listRecordParentClone) {
                Id idOldLookupRecord = recordParent.getCloneSourceId();

                if (listRecordChildLookup == null)
                    continue;

                for (SObject recordChild : listRecordChildLookup) {
                    if (recordChild.isSet(lookupFieldName) == false)
                        continue;

                    if (idOldLookupRecord == recordChild.get(lookupFieldName)) {
                        recordChild.put(lookupFieldName, recordParent.Id);
                    }
                }
            }
        }
    }

    private void buildCloneParentRelName(
        List<SObject> clonedChildrenList,
        Map<String, SObject> clonedLookup,
        String lookupRelation,
        String childRelName
    ) {
        if (clonedLookup.values() != null) {
            buildRecordInsertRelName(childRelName, clonedLookup.values());
            if (this.explodeFieldsByRelNameMap.get(lookupRelation) != null) {
                String lookupFieldName = this.explodeFieldsByRelNameMap.get(lookupRelation);
                for (SObject clonedChildren : clonedChildrenList) {
                    // set lookup fields INTEGRATEDRECORD__C = parentId Object
                    if (clonedChildren.isSet(lookupFieldName) && clonedLookup.containsKey((String) clonedChildren.get(lookupFieldName))) {
                        buildRecordChildLookupRelation(childRelName, clonedChildren);
                    }
                }
            }
        }
    }

    private void buildRecordChildLookupRelation(String childRelName, SObject recordInsert) {
        if (this.childLookupRecordInsertMap.get(childRelName) == null) {
            this.childLookupRecordInsertMap.put(childRelName, new List<SObject>());
        }
        this.childLookupRecordInsertMap.get(childRelName).add(recordInsert);
    }

    private void buildRecordInsertRelName(String childRelName, List<SObject> recordInsert) {
        if (this.recordInsertMap.get(childRelName) == null) {
            this.recordInsertMap.put(childRelName, new List<SObject>());
        }
        this.recordInsertMap.get(childRelName).addAll(recordInsert);
    }

    private List<String> buildParentSelectQuery(List<String> selectFields, String objectName) {
        List<String> fieldsSelect = new List<String>{};

        if (selectFields.size() > 0) {
            for (String field : selectFields) {
                List<String> fieldName = new List<String>{ objectName, field };
                fieldsSelect.add(String.join(fieldName, '.'));
            }
        }

        return fieldsSelect;
    }

    private string buildSelectQuery(List<String> fields, String fromObj, string whereClause) {
        String qry = 'SELECT ' + String.join(fields, ',') + ' FROM ' + fromObj;

        if (!String.isEmpty(whereClause)) {
            qry += ' WHERE ' + whereClause;
        }
        return qry;
    }

    private List<String> getAllFieldsAPIName(SObjectType objType) {
        Schema.DescribeSObjectResult objectDescribe = objType.getDescribe();
        List<String> fieldAccessCreated = getFieldListFor(objectDescribe.getName());
        // Get a map of field name and field token
        Map<String, Schema.SObjectField> fMap = objectDescribe.fields.getMap();
        List<String> selectFields = new List<String>{};
        if (fMap != null) {
            for (Schema.SObjectField ft : fMap.values()) {
                // loop through all field tokens (ft)
                Schema.DescribeFieldResult fd = ft.getDescribe(); // describe each field (fd)

                if ((fd.isAccessible() || fd.isCreateable()) && fieldAccessCreated.contains(fd.getName())) {
                    // field is creatable
                    selectFields.add(fd.getName());
                }
            }
        }
        return selectFields;
    }

    private Map<String, ChildRelationship> getChildRel() {
        Map<String, ChildRelationship> childRelationMap = new Map<String, ChildRelationship>();

        for (ChildRelationship rel : sobjectTypeClone.getDescribe().getChildRelationships()) {
            String relName = rel.getRelationshipName();
            if (relName != null) {
                childRelationMap.put(relName.toUpperCase(), rel);
            }
        }

        return childRelationMap;
    }

    private List<String> getFieldListFor(String objectApiName) {
        List<String> fieldAPINames = new List<String>();

        if (this.filterClonableFieldsMap.get(objectApiName) != null) {
            fieldAPINames.addAll(this.filterClonableFieldsMap.get(objectApiName));
        }

        fieldAPINames.add('Id');

        return fieldAPINames;
    }

    private static Map<String, List<String>> getFilterClonableFields() {
        Map<String, List<String>> fieldObjectNameMap = OBJECT_FIELDS_SETTING;

        for (CopyAccountConfiguration__mdt config : COPY_ACCOUNT_CONFIG) {
            String objectApiName = String.valueOf(config.ObjectApiName__c);

            if (fieldObjectNameMap.get(objectApiName) == null) {
                fieldObjectNameMap.put(objectApiName, new List<String>());
            }
            fieldObjectNameMap.get(objectApiName).add(String.valueOf(config.ApiName__c));
        }
        return fieldObjectNameMap;
    }

    private static List<CopyAccountConfiguration__mdt> getConfigCopyAccount() {
        return [SELECT ApiName__c, ObjectApiName__c FROM CopyAccountConfiguration__mdt WHERE IsActive__c = TRUE];
    }

    private static final Map<String, List<String>> OBJECT_FIELDS_SETTING = new Map<String, List<String>>{
        'Account' => new List<String>{ 'Id', 'Name', 'RecordTypeId', 'ermt__ParentOrganization__c', 'ParentId' },
        'ermt__Risk__c' => new List<String>{ 'Id', 'Name', 'ermt__Organization__c', 'RecordTypeId', 'ERMT__RISKPROFILE__C' },
        'ermt__Incident__c' => new List<String>{ 'Id', 'Name', 'ermt__Organization__c', 'RecordTypeId', 'INTEGRATEDRECORD__C' },
        'ermt__Control__c' => new List<String>{ 'Id', 'ermt__AssignedOrg__c' }
    };

    private Schema.SObjectType getSObjectTypeCloneByID(Id recordClone) {
        try {
            if (recordClone == null) {
                throw new DeepCloneException('Cannot locate Apex Type for null ID');
            }
            return recordClone.getSobjectType();
        } catch (DeepCloneException e) {
            throw new DeepCloneException('Cannot locate Apex Type for ID');
        }
    }
    private Map<String, ChildRelationshipProps> relationshipMap;

    private SObjectType sobjectTypeClone;

    private Map<String, String> listFieldLookupCloneMap;

    private class ChildRelationshipProps {
        public SObjectType sObjectType;
        public SObjectField field;
        public ChildRelationshipProps(ChildRelationship rel) {
            this.sObjectType = rel.getChildSObject();
            this.field = rel.getField();
        }
    }

    private class DeepCloneException extends Exception {
    }
}
