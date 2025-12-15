fx_version 'cerulean'
game 'gta5'

author 'WSS-Development'
description 'Buff System made by zStretz'
version '1.0.1'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
        '@ox_lib/init.lua',
        'config.lua'
}
server_script {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
client_script 'client.lua'

lua54 'yes'