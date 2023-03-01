import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
export default class CloneSObjectComponent extends LightningElement {
    @api recordId;
    @api objectApiName;
    @wire(getRecord, {recordId: '$recordId'}) wireRecord;
    connectedCallback() {
        console.log('ObjectName', this.objectApiName);
        console.log('wireRecord' , this.wireRecord);
    }
}
