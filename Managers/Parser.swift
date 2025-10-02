//
//  Parser.swift
//  PlaybackWithAVPlayerVC
//
//  Created by Karthi on 01/10/25.
//

import Foundation

class Parser: NSObject, XMLParserDelegate {
    private var rawString = ""
    private var currentElementName = ""

    func parser(_ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]) {
        guard elementName == "cert" || elementName == "ckc" else { return }
        rawString = ""
        currentElementName = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentElementName == "cert" ||  currentElementName == "ckc" else { return }
        rawString += string
    }

    // Parse spc or ckc data which is in xml format
    func parseData(data: Data) -> Data {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        guard
            xmlParser.parse(), !self.rawString.isEmpty,
            let decoded = Data(base64Encoded: self.rawString, options: .ignoreUnknownCharacters)
            else {
                return data
        }
        return decoded
    }
}
