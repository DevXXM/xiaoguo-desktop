// main.js
const { app, BrowserWindow, Tray, Menu, globalShortcut } = require('electron');
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

  // 彻底移除菜单
  Menu.setApplicationMenu(null);

  mainWindow.loadURL('https://www.xiaoguoai.cn');

  mainWindow.webContents.on('did-finish-load', () => {
    // 1) 显示窗口
    mainWindow.show();

    // 2) 注入“🏠”和“⟳”两个半透明按钮
    const injectCode = `
      (function() {
        const containerStyle = \`
          position: fixed;
          top: 10px;
          left: 10px;
          display: flex;
          gap: 10px;
          z-index: 999999;\`;
        const btnStyle = \`
          width: 36px; height: 36px;
          background: rgba(0,0,0,0.4);
          color: #fff;
          font-size: 18px;
          border-radius: 4px;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          user-select: none;\`;
        const container = document.createElement('div');
        container.setAttribute('style', containerStyle);

        const homeBtn = document.createElement('div');
        homeBtn.innerText = '🏠';
        homeBtn.title = '返回首页';
        homeBtn.setAttribute('style', btnStyle);
        homeBtn.onclick = () => { location.href = 'https://www.xiaoguoai.cn'; };

        const reloadBtn = document.createElement('div');
        reloadBtn.innerText = '⟳';
        reloadBtn.title = '刷新页面';
        reloadBtn.setAttribute('style', btnStyle);
        reloadBtn.onclick = () => { location.reload(); };

        container.appendChild(homeBtn);
        container.appendChild(reloadBtn);
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

function setupTray() {
  const iconPath = path.join(__dirname, 'assets', 'icon.ico');
  tray = new Tray(iconPath);
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
  tray.setToolTip('小果AI 桌面版');
  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => mainWindow.show());
}

function setupGlobalShortcuts() {
  globalShortcut.register('F11', () => {
    if (mainWindow) mainWindow.setFullScreen(!mainWindow.isFullScreen());
  });
}

app.whenReady().then(() => {
  createMainWindow();
  setupTray();
  setupGlobalShortcuts();
});

app.on('before-quit', () => app.isQuiting = true);
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  else mainWindow.show();
});
