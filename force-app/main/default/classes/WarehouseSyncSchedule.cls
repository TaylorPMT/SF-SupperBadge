global class WarehouseSyncSchedule implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new WarehouseCalloutService());
    }
}
