import Foundation
import SwiftData

@Model
class TestModel {
    var id: String
    init(id: String) { self.id = id }
}

let schema = Schema([TestModel.self])
let url = URL(fileURLWithPath: "/tmp/test.sqlite")
let modelConfiguration = ModelConfiguration(schema: schema, url: url)
print("Success")
