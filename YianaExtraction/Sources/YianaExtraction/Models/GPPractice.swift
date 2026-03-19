import GRDB

struct GPPractice: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "gp_practices"

    var odsCode: String
    var name: String
    var addressLine1: String
    var addressLine2: String?
    var town: String
    var county: String?
    var postcode: String
    var postcodeDistrict: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case odsCode = "ods_code"
        case name
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case town, county, postcode
        case postcodeDistrict = "postcode_district"
        case status
    }
}
