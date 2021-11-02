//
//  GroupDrawingMessageType.swift
//  GroupDraw
//
//  Created by Paul Franco on 11/1/21.
//

import PencilKit
import Foundation

enum GroupDrawMessageType: Codable {
    case join(drawing: PKDrawing)
    case draw(drawing: PKDrawing)
    case undo
    case clear
}
