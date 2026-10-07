import { chromium, devices } from 'playwright';
import fs from 'node:fs';
const pages = {
  tribune: 'https://tribunedelyon.fr/societe/barometre-des-lyonnais-solal-gendrin-thierry-ehrmann/',
  bonbon: 'https://www.lebonbon.fr/lyon/tech/appli-lyonnaise-plus-telechargee-france-app-store-devant-tiktok-tinder/',
  ges: 'https://www.ges-lyon.fr/lyon-pocket-lascension-fulgurante-de-lapplication-de-navigation-preferee-sur-lapp-store-2026-05-26-4391.html',
  lyonpremiere: 'https://www.lyonpremiere.fr/societe/lyon-pocket-lappli-lyonnaise-qui-cartonne-sur-lapp-store/',
  lyoncapitale: 'https://www.lyoncapitale.fr/videoslyoncapitale/les-debats/video/on-a-depasse-google-maps-et-waze-le-succes-surprise-de-lapplication-lyonnaise-lyon-pocket',
  tonic: 'https://www.tonicradio.fr/carton-plein-pour-lapplication-lyonnaise-lyon-pocket/',
  grandlyon: 'https://data.grandlyon.com/portail/fr/reutilisations/6a180dba4878280031737bb4',
};
const HIDE = `#didomi-host,.didomi-popup-open,.qc-cmp2-container,#onetrust-consent-sdk,[id^="sp_message"],.fc-consent-root,#axeptio_overlay,#cmpbox,#cmpbox2,.cmp-root,#usercentrics-root,#tarteaucitronRoot,.cky-consent-container,#cookie-notice,.cookie-banner,#gdpr-consent-tool-wrapper,iframe[src*="consent"],.sticky-ad,.ad-sticky,[class*="interstitial"]{display:none!important}
body,html{overflow:auto!important}`;
const LABELS = [/tout accepter/i,/accepter et fermer/i,/^accepter$/i,/j'accepte/i,/accept all/i,/agree/i,/continuer sans accepter/i,/^ok$/i,/fermer/i];
async function dismiss(page){
  for (let round=0; round<3; round++){
    for (const f of page.frames()){
      for (const re of LABELS){
        const b = f.getByRole('button',{name:re}).first();
        try { if (await b.isVisible({timeout:300})) { await b.click({timeout:1500}); await page.waitForTimeout(700);} } catch {}
      }
    }
  }
  await page.addStyleTag({content:HIDE}).catch(()=>{});
}
const out='press-shots'; fs.mkdirSync(out,{recursive:true});
const browser = await chromium.launch();
const ctxs = {
  '': await browser.newContext({viewport:{width:1440,height:1000},deviceScaleFactor:2,locale:'fr-FR'}),
  '-mobile': await browser.newContext({...devices['iPhone 14 Pro Max'],locale:'fr-FR'}),
};
const report=[];
for (const [name,url] of Object.entries(pages)){
  for (const [suf,ctx] of Object.entries(ctxs)){
    const page = await ctx.newPage();
    try{
      await page.goto(url,{waitUntil:'domcontentloaded',timeout:45000});
      await page.waitForTimeout(4000);
      await dismiss(page);
      await page.evaluate(()=>window.scrollTo(0,0));
      await page.waitForTimeout(2500);
      await dismiss(page);
      const h1 = await page.locator('h1').first().textContent({timeout:2000}).catch(()=>null);
      await page.screenshot({path:`${out}/${name}${suf}.png`});
      await page.screenshot({path:`${out}/${name}${suf}-full.png`,fullPage:true}).catch(()=>{});
      report.push(`${name}${suf}: ok, h1=${(h1||'').trim().slice(0,140)}`);
    }catch(e){report.push(`${name}${suf}: FAIL ${e.message.split('\n')[0]}`);}
    await page.close();
  }
}
fs.writeFileSync(`${out}/report.txt`,report.join('\n')+'\n');
await browser.close();
