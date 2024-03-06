//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

//interfaces
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PinkSpace is ERC721URIStorage, Ownable {
    error PinkSpace_PriceTooLow();
    error PinkSpace_TokenIdNotIncremented();
    error PinkSpace_ZeroValue();

    using Math for uint256;

    uint256 private s_tokenId;
    uint256 private s_tokenSold;
    uint256 public listingPrice = 0.01 ether;

    struct InfoListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool isListed;
    }

    mapping(uint256 => InfoListedToken) private idToInfoToken;
    mapping(address => uint256) private s_sellers_count; 

    constructor() ERC721("PinkSpace", "PNK") Ownable(msg.sender) {
        s_tokenId = 0;
    }

    function createToken(string memory tokenURI, uint256 bid) public payable returns (uint256) {
        if (msg.value < listingPrice) revert PinkSpace_PriceTooLow(); //price must be more than minimum listing price
        bool success = false;
        (success, s_tokenId) = s_tokenId.tryAdd(1);
        if (!success) revert PinkSpace_TokenIdNotIncremented();
        _safeMint(msg.sender, s_tokenId);
        _setTokenURI(s_tokenId, tokenURI); // URI will resolves to token's metadata  https://qwerty.../{tokenId}
        createListedToken(s_tokenId, bid);
        s_sellers_count[msg.sender]++;
        return s_tokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) public {
        idToInfoToken[tokenId] = InfoListedToken(tokenId, payable(address(this)), payable(msg.sender), price, true);
        _transfer(msg.sender, address(this), tokenId);
    }

    function getAll() public view returns (InfoListedToken[] memory) {
        uint256 totalNumber = s_tokenId; //or balanceOf(address(this))
        InfoListedToken[] memory tokens = new InfoListedToken[](totalNumber);

        for (uint256 i = 1; i <= totalNumber; i++) {
            InfoListedToken storage currentItem = idToInfoToken[i];
            tokens[i - 1] = currentItem;
        }
        return tokens;
    }

    function getUsersToken() public view returns (InfoListedToken[] memory) {
        uint256 totalNumber = s_sellers_count[msg.sender];
        InfoListedToken[] memory tokens = new InfoListedToken[](totalNumber); // TODO fix with exact number (mapping) tokenOwned[msg.sender]

        for (uint256 i = 1; i <= totalNumber; i++) {
            if (idToInfoToken[i].owner == msg.sender || idToInfoToken[i].seller == msg.sender) {
                InfoListedToken storage currentItem = idToInfoToken[i];
                tokens[i - 1] = currentItem;
            }
        }
        return tokens;
    }


    //the seller will give away token
    function sellToken(uint256 tokenId) public payable {
        uint256 price = idToInfoToken[tokenId].price;
        require(msg.value == price, "Please submit the asking price"); //TODO marketplace fee?

        address seller = idToInfoToken[tokenId].seller;
        idToInfoToken[tokenId].seller = payable(msg.sender); //owner is always the contract/marketplace
        idToInfoToken[tokenId].isListed = true;
        (, s_tokenSold) = s_tokenSold.tryAdd(1); //TODO check success
        _transfer(address(this), msg.sender, tokenId);
        approve(address(this), tokenId); //the owner - has to approve too

        // payable().transfer(listingPrice); TODO
        // payable(seller).transfer(msg.value);
    }

    function updateListPrice(uint256 _listPrice) public payable onlyOwner {
        if (_listPrice <= 0) revert PinkSpace_ZeroValue();
        listingPrice = _listPrice;
    }

    function getLatestIdToListedToken() public view returns (InfoListedToken memory) {
        uint256 currentTokenId = s_tokenId;
        return idToInfoToken[currentTokenId];
    }

    function getListedForTokenId(uint256 tokenId) public view returns (InfoListedToken memory) {
        return idToInfoToken[tokenId];
    }

    function getCurrentTokenId() public view returns (uint256) {
        return s_tokenId;
    }

    function getListedPrice() public view returns (uint256) {
        return listingPrice;
    }
}
