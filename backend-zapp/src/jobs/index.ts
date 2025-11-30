/**
 * Background Jobs
 * 
 * Initializes and manages background jobs for the application.
 */

import { bridgeDepositWatcher } from '../services/bridgeDepositWatcher.js';

/**
 * Start all background jobs
 */
export function startJobs(): void {
  console.log('[Jobs] Starting background jobs...');
  
  // Start the deposit watcher
  bridgeDepositWatcher.start();
  
  console.log('[Jobs] ✓ All background jobs started');
}

/**
 * Stop all background jobs
 */
export function stopJobs(): void {
  console.log('[Jobs] Stopping background jobs...');
  
  bridgeDepositWatcher.stop();
  
  console.log('[Jobs] ✓ All background jobs stopped');
}

/**
 * Get status of all jobs
 */
export function getJobsStatus() {
  return {
    depositWatcher: bridgeDepositWatcher.getStats(),
  };
}

export default { startJobs, stopJobs, getJobsStatus };
