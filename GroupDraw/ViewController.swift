//
//  ViewController.swift
//  GroupDraw
//
//  Created by Paul Franco on 10/31/21.
//

import UIKit
import PencilKit

class ViewController: UIViewController {
    
    private lazy var canvasView: PKCanvasView = {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        return canvasView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

