#!/usr/bin/env node

/**
 * Password Manager - Клиентский сервер
 * Запускает простой HTTP сервер для статических файлов клиента
 * 
 * Использование:
 *   node start-client.js
 *   npm run client
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = 3000;
const CLIENT_DIR = path.join(__dirname, 'client');

// Проверяем существование папки client
if (!fs.existsSync(CLIENT_DIR)) {
    console.error('\n❌ Ошибка: Папка "client" не найдена!');
    console.error('   Создайте папку client и поместите туда index.html\n');
    process.exit(1);
}

// Проверяем наличие index.html
const indexPath = path.join(CLIENT_DIR, 'index.html');
if (!fs.existsSync(indexPath)) {
    console.error('\n❌ Ошибка: Файл client/index.html не найден!');
    console.error('   Убедитесь, что index.html находится в папке client\n');
    process.exit(1);
}

// MIME типы для разных расширений
const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon'
};

// Создаем HTTP сервер
const server = http.createServer((req, res) => {
    // Нормализуем путь к файлу
    let filePath = path.join(CLIENT_DIR, req.url === '/' ? 'index.html' : req.url);
    
    // Получаем расширение файла
    const ext = path.extname(filePath);
    const contentType = mimeTypes[ext] || 'application/octet-stream';
    
    // Читаем файл
    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
                // Файл не найден
                res.writeHead(404, { 'Content-Type': 'text/html' });
                res.end('<h1>404 - Страница не найдена</h1>');
            } else {
                // Ошибка сервера
                res.writeHead(500);
                res.end(`Ошибка сервера: ${err.code}`);
            }
        } else {
            // Успешная отправка файла
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
});

// Получаем локальный IP адрес
function getLocalIP() {
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();
    
    for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
            // Пропускаем не-IPv4 и внутренние адреса
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    return 'localhost';
}

// Запускаем сервер
server.listen(PORT, '0.0.0.0', () => {
    const localIP = getLocalIP();
    
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║     🌐 Password Manager - Клиент запущен                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   📱 Доступные адреса:                                       ║
║   • Локально:    http://localhost:${PORT}                     ║
║   • По сети:     http://${localIP}:${PORT}                     ║
║                                                              ║
║   📂 Директория:  ${CLIENT_DIR}                                ║
║                                                              ║
║   ⚠️  Важно:                                                 ║
║   • Сервер должен быть запущен отдельно (node server/server.js)║
║   • Убедитесь, что порт ${PORT} не занят                        ║
║                                                              ║
║   🛑 Для остановки нажмите Ctrl+C                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
    `);
});

// Обработка завершения
process.on('SIGINT', () => {
    console.log('\n\n🛑 Клиентский сервер остановлен\n');
    process.exit();
});