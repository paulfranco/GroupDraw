//
//  GroupDrawActivity.swift
//  GroupDraw
//
//  Created by Paul Franco on 10/31/21.
//

import UIKit
import GroupActivities

struct GroupDrawActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.type = .generic
        metadata.title = "Group Drawing"
        metadata.previewImage = UIImage(systemName: "hand.draw")?.cgImage
        return metadata
    }
}
