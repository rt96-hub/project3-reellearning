import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'dev.lovable.322c8490-61f7-402a-b4fa-3382da0145b3',
  appName: 'LovableApp',
  webDir: 'dist',
  server: {
    url: 'https://322c8490-61f7-402a-b4fa-3382da0145b3.lovableproject.com?forceHideBadge=true',
    cleartext: true
  },
  ios: {
    contentInset: 'automatic'
  },
  android: {
    backgroundColor: "#ffffffff"
  }
};

export default config;