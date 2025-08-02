//
//  Image+.swift
//  RefractiveExchange
//
//  Created by Assistant
//

import SwiftUI

extension Image {
    static func adaptiveLogo(for colorScheme: ColorScheme) -> Image {
        return Image("RF Icon")
            .renderingMode(colorScheme == .dark ? .template : .original)
    }
} 