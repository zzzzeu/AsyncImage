//
//  ImageProcessor.swift
//  AsyncImage
//
//  Created by Fabian Thies on 20.12.22.
//

import UIKit

public protocol ImageProcessor {
    func process(image: UIImage) -> UIImage
}
