//
//  PasteboardManager.swift
//  Clipy
//
//  Created by 古林俊佑 on 2016/03/11.
//  Copyright © 2016年 Shunsuke Furubayashi. All rights reserved.
//

import Foundation
import Cocoa
import Crashlytics

final class PasteboardManager {
    // MARK: - Properties
    static let sharedManager = PasteboardManager()
    private let pasteboard = NSPasteboard.generalPasteboard()
    private let lock = NSRecursiveLock(name: "com.clipy-app.Clipy.Pastable")
    private let defaults = NSUserDefaults.standardUserDefaults()
    private var isPastePlainText: Bool {
        guard let flags = NSApp.currentEvent?.modifierFlags else { return false }
        if !defaults.boolForKey(Constants.Beta.pastePlainText) { return false }

        let modifierSetting = defaults.integerForKey(Constants.Beta.pastePlainTextModifier)
        if modifierSetting == 0 && flags.contains(.CommandKeyMask) {
            return true
        } else if modifierSetting == 1 && flags.contains(.ShiftKeyMask) {
            return true
        } else if modifierSetting == 2 && flags.contains(.ControlKeyMask) {
            return true
        } else if modifierSetting == 3 && flags.contains(.AlternateKeyMask) {
            return true
        }
        return false
    }
}

// MARK: - Copy
extension PasteboardManager {
    func copyStringToPasteboard(aString: String) {
        lock.lock()
        pasteboard.declareTypes([NSStringPboardType], owner: self)
        pasteboard.setString(aString, forType: NSStringPboardType)
        lock.unlock()
    }

    func copyClipToPasteboard(clip: CPYClip) {
        lock.lock()
        if let data = NSKeyedUnarchiver.unarchiveObjectWithFile(clip.dataPath) as? CPYClipData {
            let types = data.types
            let isPastePlainText = self.isPastePlainText
            pasteboard.declareTypes(types, owner: self)
            types.forEach { type in
                switch type {
                case NSStringPboardType:
                    let pbString = data.stringValue
                    pasteboard.setString(pbString, forType: NSStringPboardType)
                case NSRTFDPboardType where !isPastePlainText:
                    if let rtfData = data.RTFData {
                        pasteboard.setData(rtfData, forType: NSRTFDPboardType)
                    }
                case NSRTFPboardType where !isPastePlainText:
                    if let rtfData = data.RTFData {
                        pasteboard.setData(rtfData, forType: NSRTFPboardType)
                    }
                case NSPDFPboardType:
                    if let pdfData = data.PDF, pdfRep = NSPDFImageRep(data: pdfData) {
                        pasteboard.setData(pdfRep.PDFRepresentation, forType: NSPDFPboardType)
                    }
                case NSFilenamesPboardType:
                    let fileNames = data.fileNames
                    pasteboard.setPropertyList(fileNames, forType: NSFilenamesPboardType)
                case NSURLPboardType:
                    let url = data.URLs
                    pasteboard.setPropertyList(url, forType: NSURLPboardType)
                case NSTIFFPboardType:
                    if let image = data.image, imageData = image.TIFFRepresentation {
                        pasteboard.setData(imageData, forType: NSTIFFPboardType)
                    }
                default: break
                }
            }
        }
        lock.unlock()
    }
}

// MARK: - Paste
extension PasteboardManager {
    static func paste() {
        if !NSUserDefaults.standardUserDefaults().boolForKey(Constants.UserDefaults.inputPasteCommand) { return }

        let source = CGEventSourceCreate(.CombinedSessionState)
        // Press Command + V
        let keyVDown = CGEventCreateKeyboardEvent(source, CGKeyCode(9), true)
        CGEventSetFlags(keyVDown, .MaskCommand)
        // Release Command + V
        let keyVUp = CGEventCreateKeyboardEvent(source, CGKeyCode(9), false)
        CGEventSetFlags(keyVUp, .MaskCommand)
        // Post Paste Command
        CGEventPost(.CGAnnotatedSessionEventTap, keyVDown)
        CGEventPost(.CGAnnotatedSessionEventTap, keyVUp)
    }
}
