//
//  ViewController.swift
//  GroupDraw
//
//  Created by Paul Franco on 10/31/21.
//

import UIKit
import PencilKit
import Combine
import GroupActivities

class ViewController: UIViewController {
    
    private lazy var canvasView: PKCanvasView = {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = self
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        return canvasView
    }()
    
    private lazy var toolPicker: PKToolPicker = {
        let toolPicker = PKToolPicker()
        return toolPicker
    }()
    
    private lazy var undoBarButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: self, action: #selector(handleUndoStroke))
        button.isEnabled = false
        return button
    }()
    
    private lazy var redoBarButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: self, action: #selector(handleRedoStroke))
        button.isEnabled = false
        return button
    }()
    
    private var removedStrokes = [PKStroke]() {
        didSet {
            undoBarButtonItem.isEnabled = !canvasView.drawing.strokes.isEmpty
            redoBarButtonItem.isEnabled = !removedStrokes.isEmpty
        }
    }
    
    private var isAddedNewStroke = false
    
    private lazy var groupActivity: GroupDrawActivity = {
        let activity = GroupDrawActivity()
        return activity
    }()
    
    private lazy var startGroupActivityBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "person.2.fill"), style: .plain, target: self, action: #selector(handleStartGroupActivity))
        return barButtonItem
    }()
    
    private lazy var endGroupActivityBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "stop.circle.fill"), style: .plain, target: self, action: #selector(handleEndGroupActivity))
        return barButtonItem
    }()
    
    private var tasks = Set<Task<Void, Never>>()
    private var groupSession: GroupSession<GroupDrawActivity>?
    private var groupSessionMessenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupCanvasView()
        setupToolPicker()
        setupGroupActivitySession()
        
        navigationItem.title = "Canvas"
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action:
                                #selector(handleClearCanvas)),
            undoBarButtonItem,
            redoBarButtonItem
        ]
    
        navigationItem.rightBarButtonItems = [endGroupActivityBarButtonItem, startGroupActivityBarButtonItem]
        
        
    }
    
    private func configure(groupSession: GroupSession<GroupDrawActivity>) {
        // add code to configure group session
        let messenger = GroupSessionMessenger(session: groupSession)
        self.groupSessionMessenger = messenger
        self.groupSession = groupSession
        
        subscriptions.removeAll()
        
        groupSession.$activeParticipants.sink { [weak self] activeParticipants in
            guard let self = self else { return }
            
            // send data to all participants using groupSessionMessenger
            async {
                do {
                    try await messenger.send(GroupDrawMessageType.join(drawing: self.canvasView.drawing))
                } catch {
                    print(error)
                }
            }
            
            
        }.store(in: &subscriptions)
        
        let task = detach {
            // task to receive message via group session messenger
            for await (message, _) in messenger.messages(of: GroupDrawMessageType.self) {
                switch message {
                case .join(let drawing):
                    await self.handleJoinDrawingMessage(drawing: drawing)
                case .draw(let drawing):
                    await self.handleDrawMessage(drawing: drawing)
                case .undo:
                    await self.handleUndoMessage()
                case .clear:
                    await self.handleClearMessage()
                }
            }
        }
        tasks.insert(task)
        groupSession.join()
    }
    
    private func handleJoinDrawingMessage(drawing: PKDrawing) {
        canvasView.drawing = drawing
    }
    
    private func handleDrawMessage(drawing: PKDrawing) {
        guard let lastStroke = drawing.strokes.last else {
            return
        }
        canvasView.drawing.strokes.append(lastStroke)
    }
    
    private func handleUndoMessage() {
        undoSroke()
    }
    
    private func handleClearMessage() {
        clearCanvas()
    }
    

    private func updateGroupCanvas(stroke: PKStroke) {
        guard let messenger = groupSessionMessenger else {
            return
        }
        async {
            do {
                let drawing = PKDrawing(strokes: [stroke])
                try await messenger.send(GroupDrawMessageType.draw(drawing: drawing))
            } catch {
                print(error)
            }
        }
    }
    
    private func setupGroupActivitySession() {
        let task = detach { [weak self] in
            guard let self = self else { return }
            
            for await session in GroupDrawActivity.sessions() {
                // configure group session here
                await self.configure(groupSession: session)
            }
        }
        tasks.insert(task)
    }
    
    private func startGroupActivity() {
        async {
            setupGroupActivitySession()
            
            switch await groupActivity.prepareForActivation() {
            case .activationPreferred:
                groupActivity.activate()
            case .activationDisabled:
                print("activation disabled")
            case .cancelled:
                print("activation cancelled")
            default:
                print("unknown case")
            }
        }
    }
    
    private func clearGroupCanvas() {
        guard let messenger = groupSessionMessenger else { return }
        async {
            do {
                try await messenger.send(GroupDrawMessageType.clear)
            } catch {
                print(error)
            }
        }
    }
    
    private func redoStrokeToGroupCanvas(stroke: PKStroke?) {
        guard let messenger = groupSessionMessenger else { return }
        guard let stroke = stroke else { return }
        
        async {
            do {
                try await messenger.send(GroupDrawMessageType.draw(drawing: PKDrawing(strokes: [stroke])))
            } catch {
                print(error)
            }
        }
    }
    
    private func undoStrokeFromGroupCanvas() {
        guard let messenger = groupSessionMessenger else {
            return
        }
        
        async {
            do {
                try await messenger.send(GroupDrawMessageType.undo)
            } catch {
                print(error)
            }
        }
    }
    
    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        removedStrokes = []
    }
    
    private func redoStroke() -> PKStroke? {
        if !removedStrokes.isEmpty {
            let stroke = removedStrokes.removeLast()
            canvasView.drawing.strokes.append(stroke)
            return stroke
        }
        return nil
    }
    
    private func undoSroke() {
        if !canvasView.drawing.strokes.isEmpty {
            let stroke = canvasView.drawing.strokes.removeLast()
            removedStrokes.append(stroke)
        }
    }
    
    private func endGroupActivity() {
        if let groupSession = groupSession {
            groupSession.end()
        }
    }
    
    @objc func handleStartGroupActivity() {
        startGroupActivity()
    }
    
    @objc func handleEndGroupActivity() {
        endGroupActivity()
    }
    
    @objc func handleRedoStroke() {
        let stroke = redoStroke()
        redoStrokeToGroupCanvas(stroke: stroke)
    }
    
    @objc func handleUndoStroke() {
        undoSroke()
        undoStrokeFromGroupCanvas()
    }
    
    @objc func handleClearCanvas() {
        clearCanvas()
        clearGroupCanvas()
    }
    
    private func setupToolPicker() {
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }
    
    private func setupCanvasView() {
        view.addSubview(canvasView)
        // Adding constraints programatically
        canvasView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        canvasView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        canvasView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }

}

extension ViewController: PKCanvasViewDelegate {
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        isAddedNewStroke = true
    }
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if isAddedNewStroke {
            isAddedNewStroke = false
            removedStrokes = []
            
            if let lastStroke = canvasView.drawing.strokes.last {
                updateGroupCanvas(stroke: lastStroke)
            }
        }
    }
}

