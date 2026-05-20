# PM2 Ecosystem Configuration
# Save as ~/ecosystem.config.js
# Usage: pm2 start ecosystem.config.js

module.exports = {
  apps: [
    // =============================
    // SPARKLES BACKEND
    // =============================
    {
      name: 'sparkles-auth',
      script: './bin/auth-service',
      cwd: '/home/user/servers/sparkles',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 8081,
        NODE_ENV: 'production'
      },
      error_file: './logs/auth-error.log',
      out_file: './logs/auth-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      restart_delay: 5000,
      max_restarts: 10,
      min_uptime: '10s'
    },
    {
      name: 'sparkles-dashboard',
      script: './bin/dashboard-service',
      cwd: '/home/user/servers/sparkles',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 8082,
        NODE_ENV: 'production'
      },
      error_file: './logs/dashboard-error.log',
      out_file: './logs/dashboard-out.log'
    },
    {
      name: 'sparkles-goals',
      script: './bin/goals-service',
      cwd: '/home/user/servers/sparkles',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 8083,
        NODE_ENV: 'production'
      },
      error_file: './logs/goals-error.log',
      out_file: './logs/goals-out.log'
    },
    {
      name: 'sparkles-vault',
      script: './bin/vault-service',
      cwd: '/home/user/servers/sparkles',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 8084,
        NODE_ENV: 'production'
      },
      error_file: './logs/vault-error.log',
      out_file: './logs/vault-out.log'
    },

    // =============================
    // SPARKLES FRONTEND
    // =============================
    {
      name: 'sparkles-web',
      script: 'npm',
      args: 'run preview',
      cwd: '/home/user/servers/sparkles-web',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 5173,
        NODE_ENV: 'production'
      },
      error_file: './logs/web-error.log',
      out_file: './logs/web-out.log'
    },

    // =============================
    // DOCS PORTAL
    // =============================
    {
      name: 'docs-portal',
      script: 'npm',
      args: 'run start',
      cwd: '/home/user/servers/docs-portal',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 3032,
        NODE_ENV: 'production'
      },
      error_file: './logs/docs-error.log',
      out_file: './logs/docs-out.log'
    },

    // =============================
    // ORCHESTAI (adjust as needed)
    // =============================
    {
      name: 'orchestai-api',
      script: './bin/orchestai-service',
      cwd: '/home/user/servers/orchestai',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 9000,
        NODE_ENV: 'production'
      },
      error_file: './logs/orchestai-error.log',
      out_file: './logs/orchestai-out.log'
    }
  ]
};
