// server/include/protocol.h
#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <QString>

namespace Protocol {
namespace Commands {
// Authentication
constexpr const char* AUTHENTICATE = "authenticate";
constexpr const char* PONG = "pong";

// Directory operations
constexpr const char* LIST_DIRECTORY = "list_directory";
constexpr const char* CREATE_DIRECTORY = "create_directory";
constexpr const char* DELETE_DIRECTORY = "delete_directory";
constexpr const char* GET_FOLDER_TREE = "get_folder_tree";

// File operations
constexpr const char* DELETE_FILE = "delete_file";
constexpr const char* DELETE_MULTIPLE = "delete_multiple";
constexpr const char* UPLOAD_FILE = "upload_file";
constexpr const char* UPLOAD_FOLDER = "upload_folder";      // NEW
constexpr const char* UPLOAD_MIXED = "upload_mixed";        // NEW
constexpr const char* DOWNLOAD_FILE = "download_file";
constexpr const char* DOWNLOAD_DIRECTORY = "download_directory";
constexpr const char* DOWNLOAD_MULTIPLE = "download_multiple";
constexpr const char* CANCEL_UPLOAD = "cancel_upload";
constexpr const char* CANCEL_DOWNLOAD = "cancel_download";

// Item operations
constexpr const char* MOVE_ITEM = "move_item";
constexpr const char* MOVE_MULTIPLE = "move_multiple";
constexpr const char* RENAME_ITEM = "rename_item";

// Info operations
constexpr const char* GET_STORAGE_INFO = "get_storage_info";
constexpr const char* GET_SERVER_INFO = "get_server_info";
constexpr const char* GET_THUMBNAIL = "get_thumbnail";

// User management
constexpr const char* GET_USER_LIST = "get_user_list";
constexpr const char* CREATE_USER = "create_user";
constexpr const char* EDIT_USER = "edit_user";
constexpr const char* DELETE_USER = "delete_user";

// Sharing
constexpr const char* GENERATE_SHARE_LINK = "generate_share_link";
}

namespace Responses {
constexpr const char* ERROR = "error";
constexpr const char* PING = "ping";
constexpr const char* AUTHENTICATE = "authenticate";
constexpr const char* LIST_DIRECTORY = "list_directory";
constexpr const char* CREATE_DIRECTORY = "create_directory";
constexpr const char* DELETE_FILE = "delete_file";
constexpr const char* DELETE_DIRECTORY = "delete_directory";
constexpr const char* DELETE_MULTIPLE = "delete_multiple";
constexpr const char* UPLOAD_READY = "upload_ready";
constexpr const char* UPLOAD_COMPLETE = "upload_complete";
constexpr const char* UPLOAD_CANCELLED = "upload_cancelled";
constexpr const char* FOLDER_UPLOAD_STARTED = "folder_upload_started";   // NEW
constexpr const char* MIXED_UPLOAD_STARTED = "mixed_upload_started";     // NEW
constexpr const char* DOWNLOAD_START = "download_start";
constexpr const char* DOWNLOAD_COMPLETE = "download_complete";
constexpr const char* DOWNLOAD_CANCELLED = "download_cancelled";
constexpr const char* DOWNLOAD_ZIPPING = "download_zipping";
constexpr const char* MOVE_ITEM = "move_item";
constexpr const char* MOVE_MULTIPLE = "move_multiple";
constexpr const char* RENAME_ITEM = "rename_item";
constexpr const char* STORAGE_INFO = "storage_info";
constexpr const char* SERVER_INFO = "server_info";
constexpr const char* THUMBNAIL_DATA = "thumbnail_data";
constexpr const char* USER_CREATED = "user_created";
constexpr const char* USER_EDITED = "user_edited";
constexpr const char* USER_DELETED = "user_deleted";
constexpr const char* USER_LIST = "user_list";
constexpr const char* SHARE_LINK_GENERATED = "share_link_generated";
constexpr const char* FOLDER_TREE = "folder_tree";
}
}

#endif // PROTOCOL_H
