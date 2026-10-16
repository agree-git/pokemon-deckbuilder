class_name CardStacks
extends RefCounted
## Read-only display groups. Preserve first appearance, owner and all face details;
## only instance UID is ignored. Never alter the source cards or their order.
static func group(views: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var identities: Array[Dictionary] = []
    for view: Dictionary in views:
        var identity := view.duplicate(true)
        identity.erase("uid")
        var index := identities.find(identity)
        if index < 0:
            identities.append(identity)
            result.append({"view":view.duplicate(true),"count":1})
        else:
            result[index]["count"] += 1
    return result
