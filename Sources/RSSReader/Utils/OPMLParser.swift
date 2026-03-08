import Foundation

struct ParsedFeed {
    let title: String
    let xmlUrl: String
    let siteUrl: String?
}

struct ParsedFolder {
    let name: String
    var feeds: [ParsedFeed]
}

class OPMLParser: NSObject, XMLParserDelegate {
    private var parsedFolders: [ParsedFolder] = []
    private var parsedStandaloneFeeds: [ParsedFeed] = []
    
    // Stack to track folder hierarchy
    private var currentPath: [ParsedFolder] = []
    private var isFeedStack: [Bool] = [] // tracks element types to properly pop on didEndElement
    
    func parse(data: Data) -> (folders: [ParsedFolder], feeds: [ParsedFeed]) {
        parsedFolders = []
        parsedStandaloneFeeds = []
        currentPath = []
        isFeedStack = []
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return (parsedFolders, parsedStandaloneFeeds)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard elementName.lowercased() == "outline" else { return }
        
        let title = attributeDict["title"] ?? attributeDict["text"] ?? "İsimsiz"
        let xmlUrl = attributeDict["xmlUrl"]
        let htmlUrl = attributeDict["htmlUrl"]
        let type = attributeDict["type"]
        
        // If xmlUrl is present or type="rss", it's a feed
        if let xmlUrl = xmlUrl, !xmlUrl.isEmpty {
            isFeedStack.append(true)
            let feed = ParsedFeed(title: title, xmlUrl: xmlUrl, siteUrl: htmlUrl)
            
            if !currentPath.isEmpty {
                currentPath[currentPath.count - 1].feeds.append(feed)
            } else {
                parsedStandaloneFeeds.append(feed)
            }
        } else if type?.lowercased() == "rss" {
           // Feed without valid xmlUrl? Ignore or try to handle, safely fallback to standalone 
           isFeedStack.append(true)
        } else {
            // It's a folder
            isFeedStack.append(false)
            let folder = ParsedFolder(name: title, feeds: [])
            currentPath.append(folder)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName.lowercased() == "outline" else { return }
        guard !isFeedStack.isEmpty else { return }
        
        let isFeed = isFeedStack.removeLast()
        if !isFeed {
            if !currentPath.isEmpty {
                let finishedFolder = currentPath.removeLast()
                // Top-level folders are appended. Nested folders are currently flattened to root.
                parsedFolders.append(finishedFolder)
            }
        }
    }
}
