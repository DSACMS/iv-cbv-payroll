import { vi, describe, beforeEach, it, expect } from 'vitest'
import loadScript from "load-script";

export const mockArgyleAuthToken = { user: { user_token: 'test-token' }};

const triggers = ({ onAccountConnected, onClose}) => ({
    triggerAccountConnected: () => {
        if (onAccountConnected) {
            onAccountConnected({ accountId: 'account-id', platformId: 'platform-id' });
        }
    },
    triggerClose: () => {
        if(onClose) {
            onClose()
        }
    }
})


export const mockArgyleModule = { 
    create: vi.fn((createParams) => {
        return  {
            open: vi.fn((other) => triggers(createParams,other)),
        }
    })
} 

export const mockArgyle = () => {
    loadScript.mockImplementation((url, callback) => {
        vi.stubGlobal('Argyle', mockArgyleModule)
        callback(null, global.Argyle)
    })
}
