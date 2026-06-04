import Foundation
import Supabase

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://iysdxlrogxpeveqlpzus.supabase.co")!,
        supabaseKey: "sb_publishable_gHfKrvMEOpDnUcpm0BxZyQ_Agafitor"
    )
    
    private init() {}
}
