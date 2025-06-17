// main.js
const { app, BrowserWindow, Tray, Menu, globalShortcut, dialog } = require('electron');
const { autoUpdater } = require('electron-updater');
const path = require('path');

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

  // 去掉系统默认菜单
  Menu.setApplicationMenu(null);

  // 加载远程页面
  mainWindow.loadURL('https://www.xiaoguoai.cn');

  // 页面加载完成后显示，并注入“🏠” & “⟳” 按钮
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
        container.appendChild(makeBtn('返回首页','返回首页',()=> location.href='https://www.xiaoguoai.cn'));
        container.appendChild(makeBtn('⟳','刷新页面',()=> location.reload()));
        document.body.appendChild(container);
      })();
    `;
    mainWindow.webContents.executeJavaScript(injectCode).catch(console.error);
  });

  // “关闭”时隐藏到托盘
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
  tray.setToolTip('大嘴外语小果AI');
  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => mainWindow.show());
}

// 注册全局快捷键
function setupGlobalShortcuts() {
  globalShortcut.register('F11', () => {
    if (mainWindow) {
      mainWindow.setFullScreen(!mainWindow.isFullScreen());
    }
  });
}

// —— 自动更新事件处理 ——  
autoUpdater.on('checking-for-update', () => {
  console.log('检查更新…');
});
autoUpdater.on('update-available', info => {
  dialog.showMessageBox({
    type: 'info',
    title: '检测到新版本',
    message: `发现新版本 ${info.version}，正在下载…`
  });
});
autoUpdater.on('update-not-available', () => {
  console.log('当前已是最新版本');
});
autoUpdater.on('error', err => {
  console.error('自动更新出错:', err);
});
autoUpdater.on('download-progress', progress => {
  console.log(`下载进度: ${Math.floor(progress.percent)}%`);
});
autoUpdater.on('update-downloaded', info => {
  dialog.showMessageBox({
    type: 'question',
    title: '下载完成',
    message: `版本 ${info.version} 下载完成，是否立即安装？`,
    buttons: ['立即安装','稍后再说']
  }).then(({ response }) => {
    if (response === 0) {
      autoUpdater.quitAndInstall();
    }
  });
});

app.whenReady().then(() => {
  createMainWindow();
  setupTray();
  setupGlobalShortcuts();
  // 启动后立刻检查并下载更新
  autoUpdater.checkForUpdatesAndNotify();
});

app.on('before-quit', () => app.isQuiting = true);
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  else mainWindow.show();
});
