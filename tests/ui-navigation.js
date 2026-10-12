async function navigate(page,name) {
  if(await page.locator('#evidence-panel[data-open]').count()) await page.locator('#notes-close').click();
  if(await page.locator('body.focused').count()) await page.keyboard.press('Escape');
  if(await page.locator('#navigation-open').isVisible()) await page.locator('#navigation-open').click();
  await page.getByRole('link',{name,exact:true}).click();
}
module.exports={navigate};
