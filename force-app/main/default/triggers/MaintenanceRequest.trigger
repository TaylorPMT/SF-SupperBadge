trigger MaintenanceRequest on Case(after update) {
    if (Trigger.isUpdate && Trigger.isAfter) {
        MaintenanceRequestHelper.updateMaintenceRequest(Trigger.new);
    }
}
