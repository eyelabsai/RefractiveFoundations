//
//  CreateViewModel.swift
//  IOL CON
//
//  Created by Cole Sherman on 6/6/23.
//

import Foundation

class CreateViewModel: ObservableObject {
    @Published var didUpload = false
    
    let service = PostService()
        
    
}
