-- 네이버 수집 데이터 정리 (ingest-naver-places 규칙과 동일)
--  - 대형 프랜차이즈 제외
--  - 기간 정보가 없어 지난 행사가 섞이는 팝업 제외
--  - 음식점·쇼핑이 놀거리로 잘못 들어간 경우, PC방·용품점·체육시설 제외
--  - 이름의 HTML 기호(&lt; &gt; &amp;) 복원
UPDATE public.places
   SET is_active = FALSE
 WHERE source = 'NAVER'
   AND (
        name ~* '스타벅스|이디야|투썸|메가(엠지씨|MGC)?커피|빽다방|컴포즈|할리스|파스쿠찌|커피빈|엔제리너스|탐앤탐스|폴바셋|배스킨|던킨|파리바게|뚜레쥬르|맥도날드|버거킹|롯데리아|KFC|맘스터치|서브웨이|써브웨이|도미노|피자헛|파파존스|BBQ|비비큐|BHC|교촌|굽네|네네치킨|처갓집|김밥천국|본죽|이삭토스트|홍콩반점|새마을식당|역전할머니|한신포차|아웃백|빕스|애슐리|공차|설빙|쥬씨|요거프레소|더벤티|매머드|드롭탑|카페베네|커피나무|달콤커피|하삼동|텐퍼센트|블루샥|벌툰|코인노래|수퍼스타코인|럭키코인'
     OR category = 'POPUP'
     OR coalesce(description, '') ~ '(PC방|용품|체육센터|헬스|피트니스)'
     OR (coalesce(description, '') ~ '체육관' AND name !~ '(클라이밍|볼더링|암장)')
     OR (category = 'ACTIVITY'
         AND coalesce(description, '') ~ '(음식점|한식|양식|일식|중식|카페,디저트|술집|쇼핑|유통|화장품)'
         AND name !~ '(공방|클래스)')
   );

UPDATE public.places
   SET name = replace(replace(replace(name, '&lt;', '<'), '&gt;', '>'), '&amp;', '&')
 WHERE source = 'NAVER' AND name ~ '&(lt|gt|amp);';
