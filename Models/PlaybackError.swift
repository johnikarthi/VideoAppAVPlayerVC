//
//  PlaybackError.swift
//  PlaybackWithAVPlayerVC
//
//  Created by Karthi on 02/10/25.
//

enum PlaybackError: Error {
    case invalidURL
    case certUrlEmpty
    case certDataEmpty
    case licenseUrlMissing
    case invalidContentIdOrSKD
    case linceServerError
    case emptyCKCData
    case noData
}
