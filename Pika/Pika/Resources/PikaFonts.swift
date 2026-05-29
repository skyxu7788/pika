//
//  PikaFonts.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation
import SwiftUI

enum PikaFonts {
    static func extendedBlack(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom("Telka-ExtendedBlack", size: size, relativeTo: textStyle)
    }

    static func regular(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom("Telka-Regular", size: size, relativeTo: textStyle)
    }
}
