const express = require('express');
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 6000;

app.use(express.json());
app.use(express.static('public'));

// 执行系统命令的辅助函数
function runCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, { timeout: 30000 }, (error, stdout, stderr) => {
      if (error) {
        reject({ error, stderr });
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

// 获取打印机状态
app.get('/api/printers', async (req, res) => {
  try {
    const output = await runCommand('lpstat -p -d');
    const printers = parsePrinterStatus(output);
    res.json({ success: true, printers });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '获取打印机状态失败' });
  }
});

// 解析打印机状态
function parsePrinterStatus(output) {
  const printers = [];
  const lines = output.split('\n');
  let currentPrinter = null;

  for (const line of lines) {
    if (line.startsWith('printer ')) {
      const match = line.match(/printer\s+(\S+)\s+(.+?)(?:\s+enabled|\s+disabled|$)/);
      if (match) {
        if (currentPrinter) printers.push(currentPrinter);
        currentPrinter = {
          name: match[1],
          status: line.includes('disabled') ? 'disabled' : 'enabled',
          message: match[2] || '',
          idle: line.includes('idle'),
          printing: line.includes('printing'),
          jobs: 0
        };
      }
    }
    if (line.startsWith('Default destination:')) {
      const defaultPrinter = line.split(':')[1].trim();
      printers.forEach(p => p.isDefault = p.name === defaultPrinter);
    }
  }

  if (currentPrinter) printers.push(currentPrinter);
  return printers;
}

// 获取打印队列
app.get('/api/queue/:printer?', async (req, res) => {
  const printer = req.params.printer || '';
  const command = printer ? `lpq -P ${printer}` : 'lpq';
  
  try {
    const output = await runCommand(command);
    const jobs = parseQueue(output);
    res.json({ success: true, jobs, printer });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '获取队列失败', jobs: [] });
  }
});

// 解析打印队列
function parseQueue(output) {
  const jobs = [];
  const lines = output.split('\n');
  
  for (const line of lines) {
    const match = line.match(/(\d+)\s+(\S+)\s+(\S+)/);
    if (match) {
      jobs.push({
        id: match[1],
        user: match[2],
        file: match[3]
      });
    }
  }
  
  return jobs;
}

// 检查打印机网络连接
app.post('/api/check-network/:printer', async (req, res) => {
  const printer = req.params.printer;
  
  try {
    // 获取打印机 URI
    const uriOutput = await runCommand(`lpoptions -p ${printer} -l | grep DeviceURI || lpstat -v ${printer}`);
    const uriMatch = uriOutput.match(/(?:device-uri|DeviceURI)[:=]\s*(\S+)/i);
    const uri = uriMatch ? uriMatch[1] : null;
    
    if (!uri) {
      return res.json({ success: false, error: '无法获取打印机 URI' });
    }
    
    // 提取主机名/IP
    const hostMatch = uri.match(/(?:socket|ipp|ipps):\/\/([^:\/]+)/);
    const host = hostMatch ? hostMatch[1] : null;
    
    if (!host) {
      return res.json({ success: true, message: '本地打印机，无需网络检查', uri });
    }
    
    // Ping 检查
    const pingResult = await runCommand(`ping -c 3 -W 2 ${host} 2>&1 || echo "PING_FAILED"`);
    const isReachable = !pingResult.includes('100% packet loss') && !pingResult.includes('PING_FAILED');
    
    res.json({
      success: true,
      printer,
      uri,
      host,
      reachable: isReachable,
      pingResult: pingResult.substring(0, 500)
    });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '网络检查失败' });
  }
});

// 清除打印队列
app.post('/api/clear-queue/:printer', async (req, res) => {
  const printer = req.params.printer;
  const command = printer ? `cancel -P ${printer} -a` : 'cancel -a';
  
  try {
    await runCommand(command);
    res.json({ success: true, message: `打印机 ${printer || '所有'} 的队列已清除` });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '清除队列失败' });
  }
});

// 重启打印机服务
app.post('/api/restart-service', async (req, res) => {
  try {
    await runCommand('systemctl restart cups');
    res.json({ success: true, message: 'CUPS 服务已重启' });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '重启服务失败' });
  }
});

// 启用/禁用打印机
app.post('/api/toggle-printer/:printer/:action', async (req, res) => {
  const { printer, action } = req.params;
  const command = action === 'enable' ? `cupsenable ${printer}` : `cupsdisable ${printer}`;
  
  try {
    await runCommand(command);
    res.json({ success: true, message: `打印机 ${printer} 已${action === 'enable' ? '启用' : '禁用'}` });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '操作失败' });
  }
});

// 接受/拒绝打印任务
app.post('/api/accept-printer/:printer/:action', async (req, res) => {
  const { printer, action } = req.params;
  const command = action === 'accept' ? `cupsaccept ${printer}` : `cupsreject ${printer}`;
  
  try {
    await runCommand(command);
    res.json({ success: true, message: `打印机 ${printer} 已${action === 'accept' ? '接受' : '拒绝'}任务` });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '操作失败' });
  }
});

// 自动诊断和修复
app.post('/api/auto-fix/:printer', async (req, res) => {
  const printer = req.params.printer;
  const results = [];
  
  try {
    // 1. 检查网络
    results.push({ step: 'network', status: 'checking' });
    const networkCheck = await runCommand(`ping -c 2 -W 2 $(lpstat -v ${printer} 2>/dev/null | grep -oP '(?<=//)[^:/]+' | head -1) 2>&1 || echo "UNREACHABLE"`);
    const networkOk = !networkCheck.includes('100% packet loss') && !networkCheck.includes('UNREACHABLE');
    results[results.length - 1].status = networkOk ? 'ok' : 'failed';
    
    if (!networkOk) {
      results.push({ step: 'network_issue', message: '打印机网络不可达' });
    }
    
    // 2. 检查服务状态
    results.push({ step: 'service', status: 'checking' });
    const serviceStatus = await runCommand('systemctl is-active cups');
    const serviceOk = serviceStatus === 'active';
    results[results.length - 1].status = serviceOk ? 'ok' : 'failed';
    
    if (!serviceOk) {
      results.push({ step: 'restart_service', status: 'restarting' });
      await runCommand('systemctl restart cups');
      results[results.length - 1].status = 'done';
    }
    
    // 3. 清除卡住的队列
    const queue = await runCommand(`lpq -P ${printer} 2>/dev/null || echo ""`);
    if (queue.includes('no entries') === false && queue.trim()) {
      results.push({ step: 'clear_queue', status: 'clearing' });
      await runCommand(`cancel -P ${printer} -a`);
      results[results.length - 1].status = 'done';
    }
    
    // 4. 重新启用打印机
    results.push({ step: 'enable_printer', status: 'enabling' });
    await runCommand(`cupsenable ${printer}`);
    await runCommand(`cupsaccept ${printer}`);
    results[results.length - 1].status = 'done';
    
    res.json({ success: true, printer, results });
  } catch (error) {
    res.json({ success: false, error: error.message || '自动修复失败', results });
  }
});

// 获取系统日志
app.get('/api/logs', async (req, res) => {
  try {
    const logs = await runCommand('journalctl -u cups --no-pager -n 50');
    res.json({ success: true, logs });
  } catch (error) {
    res.json({ success: false, error: error.stderr || '获取日志失败' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Printer Monitor running on port ${PORT}`);
});
