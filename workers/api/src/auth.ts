import { createRemoteJWKSet, jwtVerify, SignJWT } from 'jose';
import { ApiError } from './model';
const keys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
export interface GoogleIdentity {sub:string; email:string; name?:string; picture?:string}
export interface GoogleTokenVerifier { verify(token:string, audience:string):Promise<GoogleIdentity> }
export class GoogleVerifier implements GoogleTokenVerifier {
 async verify(token:string,audience:string):Promise<GoogleIdentity>{
  if(!audience) throw new ApiError('AUTH_CONFIG','Google認証が設定されていません',503);
  try {
   const {payload:p}=await jwtVerify(token,keys,{algorithms:['RS256'],issuer:['https://accounts.google.com','accounts.google.com'],audience,requiredClaims:['exp','sub','email']});
   if(!p.sub || typeof p.email!=='string' || p.email_verified!==true) throw Error();
   return {sub:p.sub,email:p.email,name:typeof p.name==='string'?p.name:undefined,picture:typeof p.picture==='string'?p.picture:undefined};
  }catch {throw new ApiError('UNAUTHORIZED','Google認証を確認できませんでした',401);}
 }
}
function secret(value:string){if(!value || value.length<32)throw new ApiError('AUTH_CONFIG','認証が設定されていません',503);return new TextEncoder().encode(value);}
export async function issueSession(userId:string,value:string){return new SignJWT({}).setProtectedHeader({alg:'HS256'}).setSubject(userId).setIssuer('wadrob-api').setAudience('wadrob-mobile').setIssuedAt().setExpirationTime('7d').sign(secret(value));}
export async function verifySession(token:string,value:string){
 const key=secret(value);
 try{const {payload}=await jwtVerify(token,key,{algorithms:['HS256'],issuer:'wadrob-api',audience:'wadrob-mobile',requiredClaims:['exp','sub']}); if(!payload.sub)throw Error();return payload.sub;}catch{throw new ApiError('UNAUTHORIZED','再度ログインしてください',401);}
}
