import { vi, describe, beforeEach, it, expect } from 'vitest'
import loadScript from "load-script";

export const mockArgyleAuthToken = { user: { user_token: 'test-token' }};

export const mockArgyleModule = { 
    create: vi.fn(({onAccountConnected, onTokenExpired, onAccountCreated, onAccountError, onAccountRemoved, onClose, onError}) => {
        return  {
            open: vi.fn(),
            triggerAccountConnected: () => {
                if (onAccountConnected) {
                    onAccountConnected({ accountId: 'account-id', platformId: 'platform-id'});
                }
            },
        }
    })
} 

export const mockArgyle = () => {
    loadScript.mockImplementation((url, callback) => {
        vi.stubGlobal('Argyle', mockArgyleModule)
        callback(null, global.Argyle)
    })
}
