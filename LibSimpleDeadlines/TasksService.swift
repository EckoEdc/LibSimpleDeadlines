//
//  TasksService.swift
//  LibSimpleDeadlines
//
//  Created by Edric MILARET on 17-01-12.
//  Copyright © 2017 Edric MILARET. All rights reserved.
//

import Foundation
import AERecord
import DateHelper

public class TasksService {
    
    // MARK: - Singleton
    public static var sharedInstance = TasksService()
    
    init() {
        let model: NSManagedObjectModel = AERecord.modelFromBundle(for: TasksService.self)
        let containerURL = FileManager().containerURL(forSecurityApplicationGroupIdentifier: "group.org.auroralab.Simple-Deadlines")
        let storeURL = containerURL!.appendingPathComponent("db.sqlite")
        
        let options = [NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption: true]
        do {
            try AERecord.loadCoreDataStack(managedObjectModel: model, storeURL: storeURL, options: options)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    // MARK: - Public API
    
    public func getNewTask() -> Task {
        return Task.create()
    }
    
    public func markAsDone(task: Task) {
        task.isDone = !task.isDone
        if task.isDone {
            task.doneDate = Date() as NSDate
        } else {
            task.doneDate = nil
        }
        AERecord.save()
    }
    
    public func markAsDone(objectID: String) {
        let url = URL(string: objectID)
        if let nsObjId = AERecord.storeCoordinator?.managedObjectID(forURIRepresentation: url!) {
            if let task = AERecord.Context.main.object(with: nsObjId) as? Task{
                markAsDone(task: task)
            }
        }
    }
    
    public func deleteTask(task: Task) {
        task.delete()
        AERecord.save()
    }
    
    public func save() {
        AERecord.save()
    }
    
    public func getOrCreateCategory(name: String) -> TaskCategory {
        return TaskCategory.firstOrCreate(with: ["name" : name])
    }
    
    public func getAllCategory() -> [TaskCategory]? {
        return TaskCategory.all()
    }
    
    public func getTasks(undoneOnly: Bool = false, category: String? = nil) -> [Task] {
        var attributes: [AnyHashable: Any] = [:]
        if undoneOnly {
            attributes["isDone"] = false
        }
        if let category = category, category != "All" {
            attributes["category.name"] = category
        }
        if let response = Task.all(with: attributes, predicateType: .and, orderedBy: [NSSortDescriptor(key: "date", ascending: true)]) as? [Task] {
            return response
        } else {
            return []
        }
    }
    
    public func getFetchedResultsController(urgentOnly: Bool = false) -> NSFetchedResultsController<Task> {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        if urgentOnly {
            let now = Date()
            let threeDays = now.dateAtStartOfDay().dateByAddingDays(3).dateAtEndOfDay()
            fetchRequest.predicate = NSPredicate(format: "date <= %@ AND doneDate == nil",
                        threeDays as NSDate)
        } else {
            fetchRequest.predicate = getPredicate()
        }
        return NSFetchedResultsController<Task>(fetchRequest: fetchRequest, managedObjectContext: AERecord.Context.default, sectionNameKeyPath: nil, cacheName: nil)
    }
    
    public func filterFetchedResultsByCategory(fetchedResultsController: NSFetchedResultsController<Task>, categoryName: String? = nil) {
        fetchedResultsController.fetchRequest.predicate = getPredicate(categoryName: categoryName)
        do {
            try fetchedResultsController.performFetch()
        } catch {
            //TODO
            print("ERROR")
        }
    }
    
    // MARK: Private API
    
    func getPredicate(categoryName: String? = nil) -> NSPredicate {
        let now = Date()
        let todayStart = now.dateAtStartOfDay()
        let todayEnd = todayStart.dateAtEndOfDay()
        if let categoryName = categoryName {
            return NSPredicate(format: "(doneDate >= %@ AND doneDate <= %@ AND category.name == %@) OR (doneDate == nil AND category.name == %@)",
                               todayStart as NSDate,
                               todayEnd as NSDate,
                               categoryName,
                               categoryName)
        } else {
            return NSPredicate(format: "(doneDate >= %@ AND doneDate <= %@) OR doneDate == nil",
                               todayStart as NSDate,
                               todayEnd as NSDate)
        }
    }
}
