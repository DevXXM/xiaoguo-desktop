// main.js
const { app, BrowserWindow, Tray, Menu, globalShortcut, dialog } = require('electron');
const { autoUpdater } = require('electron-updater');
const path = require('path');
const log = require('electron-log');

// —— 自动更新日志 ——  
autoUpdater.logger = log;
autoUpdater.logger.transports.file.level = 'info';

//
// —— 代理 GitHub Releases，适用于国内网络 ——
//
autoUpdater.setFeedURL({
  provider: 'generic',
  // 这里指向你的 Release 资源目录，ghproxy 会帮你加速访问 GitHub
  url: 'https://ghproxy.com/https://github.com/DevXXM/xiaoguo-desktop/releases/download'
});

//
// —— 更新事件处理 ——  
//
autoUpdater.on('checking-for-update', () => {
  log.info('AutoUpdater: 检测更新…');
});
autoUpdater.on('update-available', info => {
  log.info('AutoUpdater: 发现新版本', info.version);
  dialog.showMessageBox({
    type: 'info',
    title: '检测到新版本',
    message: `发现新版本 ${info.version}，正在下载…`
  });
});
autoUpdater.on('update-not-available', () => {
  log.info('AutoUpdater: 未发现可用更新，当前版本：', app.getVersion());
});
autoUpdater.on('error', err => {
  log.error('AutoUpdater 错误：', err);
});
autoUpdater.on('download-progress', progress => {
  log.info(`AutoUpdater 下载进度: ${Math.floor(progress.percent)}%`);
});
autoUpdater.on('update-downloaded', info => {
  log.info('AutoUpdater: 下载完成', info.version);
  dialog.showMessageBox({
    type: 'question',
    title: '下载完成',
    message: `版本 ${info.version} 下载完成，是否立即安装？`,
    buttons: ['立即安装', '稍后再说']
  }).then(({ response }) => {
    if (response === 0) {
      autoUpdater.quitAndInstall();
    }
  });
});

let mainWindow;
let tray;

// —— 单实例保护 ——  
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
  process.exit(0);
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// 创建主窗口并注入按钮
function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1600,
    height: 900,
    show: false,
    autoHideMenuBar: true,
    icon: path.join(__dirname, 'assets', 'icon.ico'),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  Menu.setApplicationMenu(null);
  mainWindow.loadURL('https://www.xiaoguoai.cn');

  mainWindow.webContents.on('did-finish-load', () => {
    mainWindow.show();

    const injectCode = `
      (function() {
        const containerStyle = 'position:fixed;top:10px;left:10px;display:flex;gap:10px;z-index:999999;';
        const btnStyle = 'width:36px;height:36px;background:rgba(0,0,0,0.4);color:#fff;font-size:18px;border-radius:4px;display:flex;align-items:center;justify-content:center;cursor:pointer;user-select:none;';
        const container = document.createElement('div'); container.style.cssText = containerStyle;
        const makeBtn = (text, title, fn) => {
          const btn = document.createElement('div');
          btn.innerText = text; btn.title = title; btn.style.cssText = btnStyle;
          btn.onclick = fn;
          return btn;
        };
        container.appendChild(makeBtn('🏠','返回首页',()=> location.href='https://www.xiaoguoai.cn'));
        container.appendChild(makeBtn('⟳','刷新页面',()=> location.reload()));
        document.body.appendChild(container);
      })();
    `;
    mainWindow.webContents.executeJavaScript(injectCode).catch(console.error);
  });

  mainWindow.on('close', e => {
    if (!app.isQuiting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });
}

// 创建系统托盘及菜单
function setupTray() {
  tray = new Tray(path.join(__dirname, 'assets', 'icon.ico'));
  const contextMenu = Menu.buildFromTemplate([
    { label: '打开主界面', click: () => mainWindow.show() },
    { label: '切换全屏',   click: () => mainWindow.setFullScreen(!mainWindow.isFullScreen()) },
    {
      label: '打印当前页面',
      click: () => {
        if (!mainWindow.isVisible()) mainWindow.show();
        mainWindow.focus();
        mainWindow.webContents.print(
          { silent: false, printBackground: true },
          (ok, err) => { if (!ok) console.error('打印失败：', err); }
        );
      }
    },
    { type: 'separator' },
    { label: '退出',      click: () => { app.isQuiting = true; app.quit(); } }
  ]);
  tray.setToolTip('大嘴外语晓果AI');
  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => mainWindow.show());
}

// 注册全局快捷键
function setupGlobalShortcuts() {
  globalShortcut.register('F11', () => {
    if (mainWindow) mainWindow.setFullScreen(!mainWindow.isFullScreen());
  });
}

app.whenReady().then(() => {
  createMainWindow();
  setupTray();
  setupGlobalShortcuts();

  // 只有打包后才检查更新
  if (app.isPackaged) {
    log.info('应用已打包，开始检查更新…');
    log.info('当前版本：', app.getVersion());
    autoUpdater.checkForUpdatesAndNotify();
  } else {
    log.info('开发模式，不检查更新');
  }
});

app.on('before-quit', () => app.isQuiting = true);
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  else mainWindow.show();
});
