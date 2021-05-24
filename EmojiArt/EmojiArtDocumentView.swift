//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by CS193p Instructor on 4/27/20.
//  Copyright © 2020 Stanford University. All rights reserved.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(EmojiArtDocument.palette.map { String($0) }, id: \.self) { emoji in
                        Text(emoji)
                            .font(Font.system(size: self.defaultEmojiSize))
                            .onDrag { NSItemProvider(object: emoji as NSString) }
                    }
                }
            }
            .padding(.horizontal)
            
            GeometryReader { geometry in
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: self.document.backgroundImage)
                            .scaleEffect(self.zoomScale)
                            .offset(self.panOffset)
                    )
                    .gesture(self.doubleTapToZoom(in: geometry.size))
                    
                    ForEach(self.document.emojis) { emoji in
                        Text(emoji.text)
                            .onTapGesture {
                                withAnimation() {
                                    if(emoji.isSelected == false) {
                                        self.document.selectEmoji(emoji)
                                        emojis.append(emoji)
                                        
                                    } else {
                                        self.document.deselectEmoji(emoji)
                                        emojis.remove(at: emojis.firstIndex(matching: emoji)!)
                                    }
                                    print(emojis)
                                }
                            }
                            .gesture(dragEmoji(emojis: emojis))
                            .font(animatableWithSize: emoji.fontSize * self.zoomScale)
                            .position(self.position(for: emoji, in: geometry.size))
                    }
                    
                    trashCan().position(x: geometry.size.width / 2, y: 850)

                    
                }
                .clipped()
                .onTapGesture {
                    withAnimation() {
                        for emoji in self.document.emojis {
                            if emoji.isSelected == true {
                                emojis.remove(at: emojis.firstIndex(matching: emoji)!)
                            }
                            self.document.deselectEmoji(emoji)
                        }
                    }
                }
                .gesture(self.panGesture())
                .gesture( self.chooseZoomGesture())
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onDrop(of: ["public.image","public.text"], isTargeted: nil) { providers, location in
                    // SwiftUI bug (as of 13.4)? the location is supposed to be in our coordinate system
                    // however, the y coordinate appears to be in the global coordinate system
                    var location = CGPoint(x: location.x, y: geometry.convert(location, from: .global).y)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - self.panOffset.width, y: location.y - self.panOffset.height)
                    location = CGPoint(x: location.x / self.zoomScale, y: location.y / self.zoomScale)
                    return self.drop(providers: providers, at: location)
                }
                .onAppear {
                    
                    for emoji in self.document.emojis {
                        if emoji.isSelected{
                            if emojis.count != 0 {
                                emojis.remove(at: emojis.firstIndex(matching: emoji) ?? 0)
                                
                            }
                            self.document.deselectEmoji(emoji)
                            

                        }

                    }
                }
            }
            
        }
        
    }
    
    
    @State private var emojis: [EmojiArt.Emoji] = []
    @State private var offset = CGSize.zero
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    @GestureState private var gestureEmojiScale: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private  func chooseZoomGesture() -> some Gesture {
    
        if (emojis.count == 0 ) {
            return  MagnificationGesture()
                .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                    gestureZoomScale = latestGestureScale
                }
                .onEnded { finalGestureScale in
                    self.steadyStateZoomScale *= finalGestureScale
                }
        } else {
            return MagnificationGesture()
                .updating($gestureEmojiScale) { latestGestureScale, gestureEmojiScale, transaction in
                    gestureEmojiScale = latestGestureScale
                    
                    for emoji in emojis {
                        document.scaleEmoji(emoji, by: gestureEmojiScale)
                    }
                }
                .onEnded { finalGestureScale in
                    for emoji in emojis {
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                    
                }
        }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                self.steadyStateZoomScale *= finalGestureScale
            }
    }
    
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGestureValue in
                self.steadyStatePanOffset = self.steadyStatePanOffset + (finalDragGestureValue.translation / self.zoomScale)
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    self.zoomToFit(self.document.backgroundImage, in: size)
                }
            }
    }
    
    
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            self.steadyStatePanOffset = .zero
            self.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            self.document.setBackgroundURL(url)
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: location, size: self.defaultEmojiSize)
            }
        }
        return found
    }
    // MARK: -Calculate distance between two objects
    
    private func calculateDistance(emoji: EmojiArt.Emoji, trashCan: CGPoint) {
        
    }

    
    // MARK: -Gestures for Emojis
    
    private func dragEmoji(emojis: [EmojiArt.Emoji]) -> some Gesture {
        
        DragGesture()
            .onChanged {
                value in
                if (emojis.count > 0) {
                    self.document.moveEmojis(emojis, by: value.translation)
                    for emoji in emojis {
                        let emojiLocationX = Double(document.emojis[document.emojis.firstIndex(matching: emoji)!].location.x)
                        let emojiLocationY = Double(document.emojis[document.emojis.firstIndex(matching: emoji)!].location.y)
                        
                        if(emojiLocationX >= -280 && emojiLocationX <= 280 && emojiLocationY >= 350 ) {
                            deleteEmoji = true
                        } else {
                            deleteEmoji = false
                            trashCanOpacity = 0
                        }
                    }
                } else {
                    self.steadyStatePanOffset = self.steadyStatePanOffset + (value.translation / self.zoomScale)
                }
                
                trashCanOpacity = 1

            }
                
            .onEnded{_ in
             
                if(deleteEmoji){
                    document.removeEmoji(emojis: emojis)
                    deleteEmoji = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                trashCanOpacity = 0
            }
            
    }
    

    // MARK: - TrashCan
    func trashCan() -> some View {
       return Image(systemName: "trash.fill")
            .resizable()
            .frame(width: 80, height: 80)
            .opacity(trashCanOpacity)
            .rotationEffect(deleteEmoji == true ? .degrees(-360) : .degrees(0))
            .animation( deleteEmoji ? .easeInOut(duration: 1.5).repeatForever(autoreverses: false) : .default)
            .foregroundColor(.red)
    }
    // MARK: - Variables
    @State private var deleteEmoji: Bool = false
    @State private var trashCanOpacity: Double = 0
    private let defaultEmojiSize: CGFloat = 40
}
